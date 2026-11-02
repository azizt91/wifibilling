-- ==============================================================================
-- PROJECT BILLING / REVAM NET - MASTER SAAS MULTI-TENANT DATABASE SCRIPT
-- ==============================================================================
-- File ini dirancang untuk dijalankan 1 KALI (All-in-One / Idempotent) di Supabase SQL Editor.
-- Menggabungkan seluruh skema Master Database dan Migrasi SaaS Multi-Tenant (Fase 1 s/d 7).
--
-- Mencakup:
-- 1. Ekstensi Postgres (uuid-ossp, pgcrypto)
-- 2. Custom ENUM Types
-- 3. Tabel Inti SaaS (saas_plans, tenants) & Helper Default Tenant
-- 4. Tabel Operasional Aplikasi dengan tenant_id
-- 5. Indeks Performa & Unique Constraints Multi-Tenant
-- 6. Helper Auth, Role, Tenant & Trigger Otomatis (Auto Profile on Signup, Auto Tenant)
-- 7. Stored Functions & RPC Tenant-Scoped (get_all_customers, get_dashboard_stats, dll)
-- 8. Penegakan Kuota Langganan SaaS (Database-Level Quota Enforcement)
-- 9. Storage Buckets ('avatars' & 'tenant-assets') + Policies
-- 10. Data Default / Initial Seed (Plans, Default Tenant, Settings, Packages)
-- 11. Row Level Security (RLS) & Policies Menyeluruh
-- 12. Hak Akses (Grants)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EKSTENSI POSTGRES
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 2. CUSTOM ENUM TYPES (Idempotent)
-- ------------------------------------------------------------------------------
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'customer_status') THEN
        CREATE TYPE public.customer_status AS ENUM ('AKTIF', 'NONAKTIF');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
        CREATE TYPE public.invoice_status AS ENUM ('unpaid', 'paid', 'partially_paid', 'overdue');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_payment_status') THEN
        CREATE TYPE public.invoice_payment_status AS ENUM ('unpaid', 'partially_paid', 'paid', 'overdue');
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. FUNGSI DASAR & TABEL INTI SAAS MULTI-TENANT
-- ------------------------------------------------------------------------------

-- 3.0. Helper updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3.1. Konstanta ID Default Tenant (Rivamnet Default)
CREATE OR REPLACE FUNCTION public.default_tenant_id()
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT 'a0000000-0000-4000-8000-000000000001'::uuid;
$$;

-- 3.2. Tabel Paket Langganan SaaS (saas_plans)
CREATE TABLE IF NOT EXISTS public.saas_plans (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           VARCHAR(100) NOT NULL,
    slug           VARCHAR(100) NOT NULL UNIQUE,
    price_monthly  NUMERIC(12,2) NOT NULL DEFAULT 0,
    max_customers  INTEGER,                 -- Batas pelanggan WiFi per tenant (NULL = unlimited)
    features       JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT saas_plans_max_customers_chk CHECK (max_customers IS NULL OR max_customers >= 0),
    CONSTRAINT saas_plans_price_chk CHECK (price_monthly >= 0)
);

DROP TRIGGER IF EXISTS saas_plans_updated_at ON public.saas_plans;
CREATE TRIGGER saas_plans_updated_at
    BEFORE UPDATE ON public.saas_plans
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3.3. Tabel Mitra ISP / RT-RW Net (tenants)
CREATE TABLE IF NOT EXISTS public.tenants (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                     VARCHAR(150) NOT NULL,
    slug                     VARCHAR(100) NOT NULL UNIQUE,
    owner_id                 UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    plan_id                  UUID REFERENCES public.saas_plans(id) ON DELETE SET NULL,
    custom_max_customers     INTEGER DEFAULT NULL,
    subscription_status      VARCHAR(20) NOT NULL DEFAULT 'trial',
    subscription_expires_at  TIMESTAMPTZ,
    logo_url                 TEXT,
    qris_url                 TEXT,
    company_address          TEXT,
    company_phone            VARCHAR(30),
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT tenants_subscription_status_chk
        CHECK (subscription_status IN ('trial', 'active', 'past_due', 'suspended'))
);

-- Pastikan kolom custom_max_customers tersedia jika tabel sudah pernah dibuat sebelumnya
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS custom_max_customers INTEGER DEFAULT NULL;

DROP TRIGGER IF EXISTS tenants_updated_at ON public.tenants;
CREATE TRIGGER tenants_updated_at
    BEFORE UPDATE ON public.tenants
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 4. FUNGSI HELPER AUTH, ROLE & TENANT (SECURITY DEFINER)
-- ------------------------------------------------------------------------------

-- 4.1. Normalisasi Role (kanonik: super_admin, admin, pelanggan)
CREATE OR REPLACE FUNCTION public.normalize_role(p_role TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_role IS NULL THEN NULL
        WHEN lower(p_role) IN ('super_admin', 'superadmin') THEN 'super_admin'
        WHEN lower(p_role) IN ('admin', 'tenant_admin') THEN 'admin'
        WHEN lower(p_role) IN ('user', 'pelanggan', 'customer') THEN 'pelanggan'
        ELSE lower(p_role)
    END;
$$;

-- 4.2. Dapatkan Tenant ID pemanggil
CREATE OR REPLACE FUNCTION public.get_my_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant UUID;
    v_claim  TEXT;
BEGIN
    BEGIN
        v_claim := auth.jwt() -> 'app_metadata' ->> 'tenant_id';
        IF v_claim IS NOT NULL AND v_claim <> '' THEN
            v_tenant := v_claim::uuid;
        END IF;
    EXCEPTION WHEN others THEN
        v_tenant := NULL;
    END;

    IF v_tenant IS NULL AND auth.uid() IS NOT NULL THEN
        SELECT p.tenant_id INTO v_tenant FROM public.profiles p WHERE p.id = auth.uid();
    END IF;

    RETURN v_tenant;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS UUID LANGUAGE sql STABLE AS $$ SELECT public.get_my_tenant_id(); $$;

-- 4.3. Dapatkan Role pemanggil
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT p.role INTO v_role FROM public.profiles p WHERE p.id = auth.uid();

    IF v_role IS NULL THEN
        v_role := auth.jwt() -> 'app_metadata' ->> 'role';
    END IF;

    RETURN public.normalize_role(v_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(public.get_my_role() = 'super_admin', FALSE);
$$;

CREATE OR REPLACE FUNCTION public.is_tenant_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(public.get_my_role() = 'admin', FALSE);
$$;

CREATE OR REPLACE FUNCTION public.is_tenant_active(check_tenant_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE((
        SELECT t.subscription_status IN ('active', 'trial')
               AND (
                   t.subscription_expires_at IS NULL 
                   OR t.subscription_expires_at > (NOW() - INTERVAL '3 days')
               )
        FROM public.tenants t
        WHERE t.id = check_tenant_id
    ), FALSE);
$$;

CREATE OR REPLACE FUNCTION public.is_service_context()
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
    SELECT auth.uid() IS NULL
        OR COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
$$;

CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    RETURN COALESCE(user_role, 'USER');
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. TABEL-TABEL OPERASIONAL APLIKASI
-- ------------------------------------------------------------------------------

-- 5.1. Tabel Paket Internet (packages)
CREATE TABLE IF NOT EXISTS public.packages (
    id SERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    package_name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    speed_mbps INTEGER,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5.2. Tabel Profil Pengguna & Pelanggan (profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    idpl TEXT,
    full_name TEXT,
    address TEXT,
    gender TEXT,
    whatsapp_number TEXT,
    role TEXT NOT NULL DEFAULT 'USER',
    photo_url TEXT,
    status public.customer_status DEFAULT 'AKTIF',
    installation_date DATE,
    device_type TEXT,
    ip_static_pppoe TEXT,
    package_id INTEGER REFERENCES public.packages(id) ON DELETE SET NULL,
    churn_date DATE,
    latitude NUMERIC,
    longitude NUMERIC,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT profiles_tenant_required_chk CHECK (tenant_id IS NOT NULL OR upper(role) = 'SUPER_ADMIN')
);

-- 5.3. Tabel Tagihan (invoices)
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    package_id INTEGER REFERENCES public.packages(id) ON DELETE SET NULL,
    invoice_period TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    total_due NUMERIC,
    amount_paid NUMERIC DEFAULT 0,
    status public.invoice_status NOT NULL DEFAULT 'unpaid',
    due_date DATE,
    paid_at TIMESTAMPTZ,
    last_payment_date TIMESTAMPTZ,
    payment_method TEXT DEFAULT 'cash',
    broadcast_count INTEGER DEFAULT 0,
    payment_history JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5.4. Tabel Pengeluaran Operasional (expenses)
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    expense_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5.5. Tabel Notifikasi (notifications)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    recipient_role TEXT,
    recipient_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    url TEXT,
    type TEXT,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5.6. Tabel Status Baca Notifikasi (notification_reads)
CREATE TABLE IF NOT EXISTS public.notification_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_notification_user UNIQUE (notification_id, user_id)
);

-- 5.7. Tabel Metode Pembayaran (payment_methods)
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_holder TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5.8. Tabel Pengaturan Aplikasi (app_settings - 1 baris per tenant)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    app_name TEXT,
    app_short_name TEXT,
    app_description TEXT,
    app_tagline TEXT,
    logo_url TEXT,
    favicon_url TEXT,
    icon_192_url TEXT,
    icon_512_url TEXT,
    whatsapp_number TEXT,
    support_email TEXT,
    office_address TEXT,
    offline_payment_name TEXT,
    offline_payment_address TEXT,
    qris_image_url TEXT,
    show_qris BOOLEAN DEFAULT TRUE,
    theme_color TEXT,
    background_color TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT app_settings_tenant_uq UNIQUE (tenant_id)
);

-- 5.9. Tabel Pengaturan WhatsApp & Template (whatsapp_settings - key/value per tenant)
CREATE TABLE IF NOT EXISTS public.whatsapp_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value TEXT,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT whatsapp_settings_tenant_key_uq UNIQUE (tenant_id, setting_key)
);

-- 5.10. Tabel Pengaturan GenieACS (genieacs_settings - key/value per tenant)
CREATE TABLE IF NOT EXISTS public.genieacs_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value TEXT,
    is_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT genieacs_settings_tenant_key_uq UNIQUE (tenant_id, setting_key)
);

-- 5.11. Tabel Log Perubahan WiFi (wifi_change_logs)
CREATE TABLE IF NOT EXISTS public.wifi_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ip_address TEXT NOT NULL,
    old_ssid TEXT,
    new_ssid TEXT,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'pending',
    error_message TEXT
);

-- ------------------------------------------------------------------------------
-- 6. INDEKS OPTIMASI PERFORMA & UNIQUE CONSTRAINTS
-- ------------------------------------------------------------------------------
-- Indeks Tenant ID
CREATE INDEX IF NOT EXISTS idx_tenants_owner_id ON public.tenants(owner_id);
CREATE INDEX IF NOT EXISTS idx_tenants_plan_id ON public.tenants(plan_id);
CREATE INDEX IF NOT EXISTS idx_tenants_subscription_status ON public.tenants(subscription_status);
CREATE INDEX IF NOT EXISTS idx_packages_tenant_id ON public.packages(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_role_status ON public.profiles(tenant_id, role, status);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_id ON public.invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_customer ON public.invoices(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_period ON public.invoices(tenant_id, invoice_period);
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_id ON public.expenses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_date ON public.expenses(tenant_id, expense_date);
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON public.notifications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_tenant_id ON public.payment_methods(tenant_id);
CREATE INDEX IF NOT EXISTS idx_app_settings_tenant_id ON public.app_settings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_settings_tenant_id ON public.whatsapp_settings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_genieacs_settings_tenant_id ON public.genieacs_settings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_wifi_change_logs_tenant_id ON public.wifi_change_logs(tenant_id);

-- Indeks Operasional Lainnya
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);
CREATE INDEX IF NOT EXISTS idx_profiles_package_id ON public.profiles(package_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON public.invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices(status);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_role, recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notification_reads_user ON public.notification_reads(user_id);

-- Constraint Composite Unique IDPL per-tenant
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_tenant_idpl_uq;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_tenant_idpl_uq UNIQUE (tenant_id, idpl);

-- ------------------------------------------------------------------------------
-- 7. TRIGGER INTEGRITAS TENANT & OTOMASI USER
-- ------------------------------------------------------------------------------

-- 7.1. Turunan tenant_id dari customer
CREATE OR REPLACE FUNCTION public.set_tenant_from_customer()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tenant UUID;
BEGIN
    IF NEW.customer_id IS NOT NULL THEN
        SELECT tenant_id INTO v_tenant FROM public.profiles WHERE id = NEW.customer_id;
        IF v_tenant IS NOT NULL THEN NEW.tenant_id := v_tenant; END IF;
    END IF;
    IF NEW.tenant_id IS NULL THEN NEW.tenant_id := public.get_my_tenant_id(); END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS invoices_set_tenant ON public.invoices;
CREATE TRIGGER invoices_set_tenant
    BEFORE INSERT OR UPDATE OF customer_id ON public.invoices
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_from_customer();

DROP TRIGGER IF EXISTS wifi_change_logs_set_tenant ON public.wifi_change_logs;
CREATE TRIGGER wifi_change_logs_set_tenant
    BEFORE INSERT OR UPDATE OF customer_id ON public.wifi_change_logs
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_from_customer();

-- 7.2. Turunan tenant_id dari recipient notifikasi
CREATE OR REPLACE FUNCTION public.set_tenant_from_recipient()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF NEW.tenant_id IS NULL AND NEW.recipient_user_id IS NOT NULL THEN
        SELECT tenant_id INTO NEW.tenant_id FROM public.profiles WHERE id = NEW.recipient_user_id;
    END IF;
    IF NEW.tenant_id IS NULL THEN NEW.tenant_id := public.get_my_tenant_id(); END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_set_tenant ON public.notifications;
CREATE TRIGGER notifications_set_tenant
    BEFORE INSERT ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_from_recipient();

-- 7.3. Sinkronisasi Profile claims ke auth.users raw_app_meta_data
CREATE OR REPLACE FUNCTION public.sync_profile_claims_to_auth()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
BEGIN
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object(
            'tenant_id', NEW.tenant_id,
            'role', public.normalize_role(NEW.role)
        )
    WHERE id = NEW.id
      AND (
          raw_app_meta_data ->> 'tenant_id' IS DISTINCT FROM NEW.tenant_id::text
          OR raw_app_meta_data ->> 'role' IS DISTINCT FROM public.normalize_role(NEW.role)
      );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_sync_claims ON public.profiles;
CREATE TRIGGER profiles_sync_claims
    AFTER INSERT OR UPDATE OF role, tenant_id ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.sync_profile_claims_to_auth();

-- 7.4. Helper inisialisasi default settings untuk tenant baru
CREATE OR REPLACE FUNCTION public.init_tenant_defaults(p_tenant_id UUID, p_company_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_name TEXT := COALESCE(NULLIF(trim(p_company_name), ''), 'WiFi Billing');
BEGIN
    INSERT INTO public.app_settings (
        tenant_id, app_name, app_short_name, app_tagline, app_description,
        offline_payment_name, show_qris, theme_color, background_color
    ) VALUES (
        p_tenant_id, v_name, left(v_name, 12), 'Internet Cepat & Tanpa Batas',
        'Sistem Manajemen Tagihan & Layanan Pelanggan Internet WiFi',
        'Kasir ' || v_name, TRUE, '#683fe4', '#f9f8fc'
    ) ON CONFLICT (tenant_id) DO NOTHING;

    INSERT INTO public.whatsapp_settings (tenant_id, setting_key, setting_value, is_enabled) VALUES
    (p_tenant_id, 'auto_notification_enabled', 'true', TRUE),
    (p_tenant_id, 'fonnte_token', '', TRUE),
    (p_tenant_id, 'app_url', '', TRUE),
    (p_tenant_id, 'default_admin_phone', '', TRUE),
    (p_tenant_id, 'auto_send_manual_payment', 'true', TRUE),
    (p_tenant_id, 'send_on_invoice_created', 'true', TRUE),
    (p_tenant_id, 'template_custom_message',
'Informasi Tagihan WiFi Anda

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

Informasi tagihan Bapak/Ibu bulan ini adalah:
Jumlah Tagihan: {total_tagihan}
Periode Tagihan: {periode}

Metode Pembayaran:
{metode_pembayaran}

Terima kasih atas kepercayaan Anda menggunakan layanan kami.
_____________________________
*Ini adalah pesan otomatis. Jika telah membayar tagihan, abaikan pesan ini.*', TRUE),
    (p_tenant_id, 'template_payment_full',
'Konfirmasi Pembayaran LUNAS

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

✅ *TAGIHAN TELAH LUNAS!*

*Detail Pembayaran:*
• Periode: *{periode}*
• Total Tagihan: *{total_tagihan}*
• Metode: {metode_pembayaran}
• Status: *LUNAS*

Terima kasih atas pembayaran Anda.
_____________________________
*Pesan otomatis dari ' || v_name || '*', TRUE),
    (p_tenant_id, 'template_payment_installment',
'Konfirmasi Pembayaran Cicilan

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

✅ *Pembayaran cicilan diterima!*

*Detail Pembayaran:*
• Periode: *{periode}*
• Jumlah Dibayar: *{jumlah_dibayar}*
• Metode: {metode_pembayaran}
• Sisa Tagihan: *{sisa_tagihan}*

Terima kasih atas pembayaran Anda.
_____________________________
*Pesan otomatis dari ' || v_name || '*', TRUE)
    ON CONFLICT (tenant_id, setting_key) DO NOTHING;

    INSERT INTO public.genieacs_settings (tenant_id, setting_key, setting_value, is_enabled) VALUES
    (p_tenant_id, 'genieacs_enabled', 'false', FALSE),
    (p_tenant_id, 'genieacs_url', '', TRUE),
    (p_tenant_id, 'genieacs_username', '', TRUE),
    (p_tenant_id, 'genieacs_password', '', TRUE)
    ON CONFLICT (tenant_id, setting_key) DO NOTHING;
END;
$$;

-- 7.5. Helper slug unik
CREATE OR REPLACE FUNCTION public.generate_tenant_slug(p_name TEXT)
RETURNS TEXT LANGUAGE plpgsql VOLATILE SET search_path = public AS $$
DECLARE
    v_base TEXT;
    v_slug TEXT;
BEGIN
    v_base := lower(regexp_replace(COALESCE(p_name, ''), '[^a-zA-Z0-9]+', '-', 'g'));
    v_base := trim(BOTH '-' FROM v_base);
    IF v_base = '' THEN v_base := 'tenant'; END IF;
    v_base := left(v_base, 40);
    v_base := trim(BOTH '-' FROM v_base);

    LOOP
        v_slug := v_base || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.tenants WHERE slug = v_slug);
    END LOOP;
    RETURN v_slug;
END;
$$;

-- 7.6. Trigger handle_new_user (Multi-Tenant Auto-Creation)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
    v_full_name   TEXT := COALESCE(NEW.raw_user_meta_data ->> 'full_name', '');
    v_tenant_id   UUID;
    v_role        TEXT;
    v_company     TEXT;
    v_plan_id     UUID;
    v_trial_days  INTEGER;
BEGIN
    BEGIN
        v_tenant_id := NULLIF(NEW.raw_app_meta_data ->> 'tenant_id', '')::uuid;
    EXCEPTION WHEN others THEN
        v_tenant_id := NULL;
    END;

    IF v_tenant_id IS NOT NULL THEN
        -- Skenario B: Pelanggan yang dibuat oleh Admin via Edge Function
        v_role := CASE
            WHEN public.normalize_role(NEW.raw_app_meta_data ->> 'role') = 'admin' THEN 'ADMIN'
            ELSE 'USER'
        END;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id)
        VALUES (NEW.id, v_full_name, v_role, 'AKTIF', 'assets/avatar_male.svg', v_tenant_id)
        ON CONFLICT (id) DO UPDATE SET
            full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
            role      = EXCLUDED.role,
            tenant_id = EXCLUDED.tenant_id;
    ELSE
        -- Skenario A: Registrasi Tenant/Mitra Baru dari register.html
        v_company := COALESCE(
            NULLIF(trim(NEW.raw_user_meta_data ->> 'company_name'), ''),
            NULLIF(trim(v_full_name), ''),
            split_part(COALESCE(NEW.email, 'tenant'), '@', 1)
        );

        SELECT id, COALESCE((features ->> 'trial_days')::int, 14)
          INTO v_plan_id, v_trial_days
        FROM public.saas_plans
        WHERE slug = 'free-trial'
        LIMIT 1;

        INSERT INTO public.tenants (
            name, slug, owner_id, plan_id, subscription_status, subscription_expires_at
        ) VALUES (
            v_company,
            public.generate_tenant_slug(v_company),
            NEW.id,
            v_plan_id,
            'trial',
            NOW() + make_interval(days => COALESCE(v_trial_days, 14))
        )
        RETURNING id INTO v_tenant_id;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id)
        VALUES (NEW.id, v_full_name, 'ADMIN', 'AKTIF', 'assets/avatar_male.svg', v_tenant_id)
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            role      = 'ADMIN',
            tenant_id = EXCLUDED.tenant_id;

        PERFORM public.init_tenant_defaults(v_tenant_id, v_company);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 8. PENEGAKAN KUOTA & STATUS SAAS (DATABASE-LEVEL ENFORCEMENT)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_tenant_quota(p_tenant_id UUID DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_tenant_id UUID := COALESCE(p_tenant_id, public.get_my_tenant_id());
    v_max       INTEGER;
    v_plan_name TEXT;
    v_used      INTEGER;
    v_active    BOOLEAN;
    v_status    TEXT;
    v_expires   TIMESTAMPTZ;
BEGIN
    IF NOT public.is_service_context() AND NOT public.is_super_admin() AND v_tenant_id IS DISTINCT FROM public.get_my_tenant_id() THEN
        RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
    END IF;

    SELECT 
        CASE 
            WHEN t.custom_max_customers = -1 THEN NULL
            WHEN t.custom_max_customers IS NOT NULL THEN t.custom_max_customers
            ELSE sp.max_customers
        END,
        sp.name, 
        t.subscription_status, 
        t.subscription_expires_at
      INTO v_max, v_plan_name, v_status, v_expires
    FROM public.tenants t
    LEFT JOIN public.saas_plans sp ON sp.id = t.plan_id
    WHERE t.id = v_tenant_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('tenant_id', v_tenant_id, 'error', 'Tenant tidak ditemukan');
    END IF;

    SELECT COUNT(*)::INTEGER INTO v_used
    FROM public.profiles p
    WHERE p.tenant_id = v_tenant_id
      AND public.normalize_role(p.role) = 'pelanggan'
      AND p.status = 'AKTIF';

    v_active := public.is_tenant_active(v_tenant_id);

    RETURN jsonb_build_object(
        'tenant_id', v_tenant_id,
        'plan_name', v_plan_name,
        'subscription_status', v_status,
        'subscription_expires_at', v_expires,
        'is_active', v_active,
        'max_customers', v_max,
        'used_customers', v_used,
        'remaining', CASE WHEN v_max IS NULL THEN NULL ELSE GREATEST(v_max - v_used, 0) END,
        'can_add_customer', v_active AND (v_max IS NULL OR v_used < v_max)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.check_tenant_customer_quota()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_max     INTEGER;
    v_used    INTEGER;
    v_status  TEXT;
    v_expires TIMESTAMPTZ;
BEGIN
    IF public.normalize_role(NEW.role) <> 'pelanggan' OR NEW.status IS DISTINCT FROM 'AKTIF' OR NEW.tenant_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND public.normalize_role(OLD.role) = 'pelanggan' AND OLD.status = 'AKTIF' AND OLD.tenant_id = NEW.tenant_id THEN
        RETURN NEW;
    END IF;

    IF public.is_super_admin() THEN
        RETURN NEW;
    END IF;

    SELECT 
        CASE 
            WHEN t.custom_max_customers = -1 THEN NULL
            WHEN t.custom_max_customers IS NOT NULL THEN t.custom_max_customers
            ELSE sp.max_customers
        END,
        t.subscription_status, 
        t.subscription_expires_at
      INTO v_max, v_status, v_expires
    FROM public.tenants t
    LEFT JOIN public.saas_plans sp ON sp.id = t.plan_id
    WHERE t.id = NEW.tenant_id
    FOR UPDATE OF t;

    IF NOT FOUND THEN RAISE EXCEPTION 'Tenant tidak ditemukan.'; END IF;

    IF NOT public.is_tenant_active(NEW.tenant_id) THEN
        RAISE EXCEPTION 'Masa aktif langganan SaaS Anda telah berakhir atau ditangguhkan (status: %). Silakan hubungi penyedia layanan.',
            CASE WHEN v_status IN ('active', 'trial') AND v_expires IS NOT NULL AND v_expires <= NOW() THEN 'expired' ELSE v_status END;
    END IF;

    IF v_max IS NOT NULL THEN
        SELECT COUNT(*)::INTEGER INTO v_used
        FROM public.profiles p
        WHERE p.tenant_id = NEW.tenant_id
          AND public.normalize_role(p.role) = 'pelanggan'
          AND p.status = 'AKTIF'
          AND p.id <> NEW.id;

        IF v_used >= v_max THEN
            RAISE EXCEPTION 'Kuota pelanggan untuk akun Anda telah penuh (% dari maks % pelanggan). Silakan upgrade kuota Anda.', v_used, v_max;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_check_tenant_quota ON public.profiles;
CREATE TRIGGER profiles_check_tenant_quota
    BEFORE INSERT OR UPDATE OF role, status, tenant_id ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.check_tenant_customer_quota();

-- ------------------------------------------------------------------------------
-- 9. STORED FUNCTIONS & RPC LENGKAP (TENANT-SCOPED)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._assert_admin()
RETURNS VOID LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF public.is_service_context() OR public.is_super_admin() OR public.is_tenant_admin() THEN RETURN; END IF;
    RAISE EXCEPTION 'Akses ditolak: hanya admin yang dapat menjalankan fungsi ini.' USING ERRCODE = '42501';
END;
$$;

CREATE OR REPLACE FUNCTION public._tenant_visible(p_tenant_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT public.is_service_context() OR public.is_super_admin() OR p_tenant_id = public.get_my_tenant_id();
$$;

-- 9.1. Get User Email
CREATE OR REPLACE FUNCTION public.get_user_email(user_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
    user_email TEXT;
    v_target_tenant UUID;
BEGIN
    IF NOT (public.is_service_context() OR public.is_super_admin() OR user_id = auth.uid()) THEN
        SELECT tenant_id INTO v_target_tenant FROM public.profiles WHERE id = user_id;
        IF NOT public.is_tenant_admin() OR v_target_tenant IS DISTINCT FROM public.get_my_tenant_id() THEN
            RETURN '';
        END IF;
    END IF;
    SELECT email INTO user_email FROM auth.users WHERE id = user_id;
    RETURN COALESCE(user_email, '');
END;
$$;

-- 9.2. Tambah Notifikasi Pembayaran (add_payment_notification)
CREATE OR REPLACE FUNCTION public.add_payment_notification(
    customer_name TEXT,
    customer_idpl TEXT,
    invoice_period TEXT,
    amount NUMERIC,
    admin_name TEXT
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    notification_id UUID;
    formatted_amount TEXT;
    v_tenant UUID := public.get_my_tenant_id();
BEGIN
    formatted_amount := 'Rp ' || to_char(amount, 'FM999,999,999');

    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, url)
    VALUES (
        v_tenant,
        'Pembayaran Lunas Diterima',
        'Dari ' || customer_name || ' (' || customer_idpl || ') sebesar ' || formatted_amount || ' untuk periode ' || invoice_period || '. Diproses oleh ' || admin_name || '.',
        'ADMIN',
        '/tagihan.html?status=paid'
    )
    RETURNING id INTO notification_id;

    RETURN notification_id;
END;
$$;

-- 9.3. Broadcast ke Semua Admin Tenant
CREATE OR REPLACE FUNCTION public.broadcast_to_all_admins(
    notification_type TEXT,
    title TEXT,
    message TEXT,
    data JSONB DEFAULT '{}'::jsonb,
    url TEXT DEFAULT NULL
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_tenant UUID := public.get_my_tenant_id();
    admin_count INTEGER := 0;
BEGIN
    IF v_tenant IS NULL THEN RAISE EXCEPTION 'Tenant tidak diketahui.'; END IF;

    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, url, type, data)
    VALUES (v_tenant, title, message, 'ADMIN', url, notification_type, data);

    SELECT COUNT(*) INTO admin_count
    FROM public.profiles
    WHERE tenant_id = v_tenant AND public.normalize_role(role) = 'admin';

    RETURN 'Notification sent to ' || admin_count || ' admins';
END;
$$;

-- 9.4. Pembuatan Tagihan Bulanan Otomatis (create_monthly_invoices_v3)
CREATE OR REPLACE FUNCTION public.create_monthly_invoices_v3(
    p_month INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    target_invoice_period TEXT;
    created_invoices_count INTEGER := 0;
    customer_record RECORD;
    month_name TEXT;
    target_date DATE;
    target_m INTEGER;
    target_y INTEGER;
    v_all_tenants BOOLEAN;
    v_my_tenant UUID;
BEGIN
    PERFORM public._assert_admin();

    v_all_tenants := public.is_service_context() OR public.is_super_admin();
    v_my_tenant := public.get_my_tenant_id();

    IF NOT v_all_tenants AND NOT public.is_tenant_active(v_my_tenant) THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Masa aktif langganan SaaS Anda telah berakhir.');
    END IF;

    target_date := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
    target_m := COALESCE(p_month, EXTRACT(MONTH FROM target_date)::INTEGER);
    target_y := COALESCE(p_year, EXTRACT(YEAR FROM target_date)::INTEGER);

    SELECT CASE target_m
        WHEN 1 THEN 'Januari' WHEN 2 THEN 'Februari' WHEN 3 THEN 'Maret'
        WHEN 4 THEN 'April' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Juni'
        WHEN 7 THEN 'Juli' WHEN 8 THEN 'Agustus' WHEN 9 THEN 'September'
        WHEN 10 THEN 'Oktober' WHEN 11 THEN 'November' WHEN 12 THEN 'Desember'
    END INTO month_name;

    target_invoice_period := month_name || ' ' || target_y;

    FOR customer_record IN
        SELECT prof.id AS customer_id, prof.tenant_id AS customer_tenant_id,
               pack.price AS customer_price, pack.id AS customer_package_id
        FROM public.profiles prof
        JOIN public.packages pack ON prof.package_id = pack.id AND pack.tenant_id = prof.tenant_id
        WHERE public.normalize_role(prof.role) = 'pelanggan'
          AND prof.status = 'AKTIF'
          AND ((v_all_tenants AND public.is_tenant_active(prof.tenant_id)) OR (NOT v_all_tenants AND prof.tenant_id = v_my_tenant))
          AND NOT EXISTS (
              SELECT 1 FROM public.invoices inv
              WHERE inv.customer_id = prof.id AND inv.invoice_period = target_invoice_period
          )
    LOOP
        INSERT INTO public.invoices (
            tenant_id, customer_id, package_id, invoice_period,
            amount, total_due, status, due_date
        ) VALUES (
            customer_record.customer_tenant_id,
            customer_record.customer_id,
            customer_record.customer_package_id,
            target_invoice_period,
            customer_record.customer_price,
            customer_record.customer_price,
            'unpaid',
            (target_y || '-' || LPAD(target_m::TEXT, 2, '0') || '-20')::DATE
        );
        created_invoices_count := created_invoices_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Generated ' || created_invoices_count || ' invoices for ' || target_invoice_period,
        'count', created_invoices_count,
        'period', target_invoice_period
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

-- 9.5. Get All Customers (get_all_customers)
CREATE OR REPLACE FUNCTION public.get_all_customers(
    p_filter TEXT DEFAULT 'all',
    p_search_term TEXT DEFAULT ''
) RETURNS TABLE(
    id UUID, idpl TEXT, full_name TEXT, address TEXT, gender TEXT, whatsapp_number TEXT,
    role TEXT, photo_url TEXT, status public.customer_status, installation_date DATE,
    device_type TEXT, ip_static_pppoe TEXT, created_at TIMESTAMPTZ, churn_date DATE
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM public._assert_admin();

    RETURN QUERY
    SELECT
        p.id, p.idpl, p.full_name, p.address, p.gender, p.whatsapp_number,
        p.role, p.photo_url, p.status, p.installation_date, p.device_type,
        p.ip_static_pppoe, p.created_at, p.churn_date
    FROM public.profiles p
    WHERE public.normalize_role(p.role) = 'pelanggan'
      AND public._tenant_visible(p.tenant_id)
      AND (
          p_filter = 'all'
          OR (p_filter = 'active' AND p.status = 'AKTIF')
          OR (p_filter = 'inactive' AND p.status = 'NONAKTIF')
      )
      AND (
          p_search_term = ''
          OR p.full_name ILIKE '%' || p_search_term || '%'
          OR p.idpl ILIKE '%' || p_search_term || '%'
          OR p.address ILIKE '%' || p_search_term || '%'
          OR p.whatsapp_number ILIKE '%' || p_search_term || '%'
      )
    ORDER BY p.created_at DESC;
END;
$$;

-- 9.6. Dashboard Statistics (get_dashboard_stats)
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(
    p_month INTEGER DEFAULT 0,
    p_year INTEGER DEFAULT (EXTRACT(YEAR FROM CURRENT_DATE))::INTEGER
) RETURNS TABLE(
    total_revenue NUMERIC,
    total_expenses NUMERIC,
    profit NUMERIC,
    active_customers INTEGER,
    inactive_customers INTEGER,
    unpaid_invoices_count INTEGER,
    paid_invoices_count INTEGER
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_total_revenue NUMERIC := 0;
    v_total_expenses NUMERIC := 0;
    v_active_customers INTEGER := 0;
    v_inactive_customers INTEGER := 0;
    v_unpaid_invoices_count INTEGER := 0;
    v_paid_invoices_count INTEGER := 0;
BEGIN
    PERFORM public._assert_admin();

    SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_revenue
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND (p_month = 0 OR EXTRACT(MONTH FROM COALESCE(last_payment_date, paid_at, created_at)) = p_month)
      AND (p_year = 0 OR EXTRACT(YEAR FROM COALESCE(last_payment_date, paid_at, created_at)) = p_year)
      AND amount_paid > 0;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.expenses
    WHERE public._tenant_visible(tenant_id)
      AND (p_month = 0 OR EXTRACT(MONTH FROM expense_date) = p_month)
      AND (p_year = 0 OR EXTRACT(YEAR FROM expense_date) = p_year);

    SELECT
        COUNT(CASE WHEN status = 'AKTIF' THEN 1 END),
        COUNT(CASE WHEN status = 'NONAKTIF' THEN 1 END)
    INTO v_active_customers, v_inactive_customers
    FROM public.profiles
    WHERE public.normalize_role(role) = 'pelanggan'
      AND public._tenant_visible(tenant_id);

    SELECT
        COUNT(CASE WHEN status = 'unpaid' THEN 1 END),
        COUNT(CASE WHEN status = 'paid' THEN 1 END)
    INTO v_unpaid_invoices_count, v_paid_invoices_count
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND (p_month = 0 OR EXTRACT(MONTH FROM created_at) = p_month)
      AND (p_year = 0 OR EXTRACT(YEAR FROM created_at) = p_year);

    RETURN QUERY SELECT
        v_total_revenue,
        v_total_expenses,
        v_total_revenue - v_total_expenses,
        v_active_customers,
        v_inactive_customers,
        v_unpaid_invoices_count,
        v_paid_invoices_count;
END;
$$;

-- 9.7. Dashboard Charts (get_dashboard_charts_data)
CREATE OR REPLACE FUNCTION public.get_dashboard_charts_data(p_months INTEGER DEFAULT 6)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    chart_data JSONB := '[]'::jsonb;
    month_cursor DATE;
    start_date DATE;
    m_name TEXT;
    m_num INTEGER;
    y_num INTEGER;
    rev NUMERIC;
    exp NUMERIC;
BEGIN
    PERFORM public._assert_admin();

    start_date := (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL)::DATE;

    FOR i IN 0..(p_months - 1) LOOP
        month_cursor := (start_date + (i || ' months')::INTERVAL)::DATE;
        m_num := EXTRACT(MONTH FROM month_cursor)::INTEGER;
        y_num := EXTRACT(YEAR FROM month_cursor)::INTEGER;

        SELECT CASE m_num
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Agu' WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Okt' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Des'
        END INTO m_name;

        SELECT COALESCE(SUM(amount_paid), 0) INTO rev
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id)
          AND EXTRACT(MONTH FROM COALESCE(last_payment_date, paid_at, created_at)) = m_num
          AND EXTRACT(YEAR FROM COALESCE(last_payment_date, paid_at, created_at)) = y_num;

        SELECT COALESCE(SUM(amount), 0) INTO exp
        FROM public.expenses
        WHERE public._tenant_visible(tenant_id)
          AND EXTRACT(MONTH FROM expense_date) = m_num
          AND EXTRACT(YEAR FROM expense_date) = y_num;

        chart_data := chart_data || jsonb_build_object(
            'period', m_name || ' ' || y_num,
            'revenue', rev,
            'expense', exp,
            'profit', rev - exp
        );
    END LOOP;

    RETURN chart_data;
END;
$$;

-- 9.8. Get Invoices With Payment Info
CREATE OR REPLACE FUNCTION public.get_invoices_with_payment_info(
    p_status TEXT DEFAULT 'all',
    p_customer_id UUID DEFAULT NULL
) RETURNS TABLE(
    id UUID, customer_id UUID, customer_name TEXT, whatsapp_number TEXT,
    invoice_period TEXT, total_due NUMERIC, amount_paid NUMERIC,
    remaining_amount NUMERIC, status public.invoice_status, due_date DATE,
    last_payment_date TIMESTAMPTZ, payment_count INTEGER, created_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_is_admin BOOLEAN := public.is_service_context() OR public.is_super_admin() OR public.is_tenant_admin();
BEGIN
    RETURN QUERY
    SELECT
        inv.id, inv.customer_id, p.full_name AS customer_name, p.whatsapp_number,
        inv.invoice_period,
        COALESCE(inv.total_due, inv.amount) AS total_due,
        COALESCE(inv.amount_paid, 0) AS amount_paid,
        (COALESCE(inv.total_due, inv.amount) - COALESCE(inv.amount_paid, 0)) AS remaining_amount,
        inv.status, inv.due_date, inv.last_payment_date,
        COALESCE(jsonb_array_length(inv.payment_history), 0)::INTEGER AS payment_count,
        inv.created_at
    FROM public.invoices inv
    JOIN public.profiles p ON inv.customer_id = p.id
    WHERE public._tenant_visible(inv.tenant_id)
      AND (v_is_admin OR inv.customer_id = auth.uid())
      AND (p_customer_id IS NULL OR inv.customer_id = p_customer_id)
      AND (
          p_status = 'all'
          OR (p_status = 'paid' AND inv.status = 'paid')
          OR (p_status = 'unpaid' AND inv.status IN ('unpaid', 'partially_paid'))
          OR (p_status = 'overdue' AND inv.status = 'overdue')
      )
    ORDER BY inv.created_at DESC;
END;
$$;

-- 9.9. Process Installment Payment (process_installment_payment)
CREATE OR REPLACE FUNCTION public.process_installment_payment(
    p_invoice_id UUID,
    p_payment_amount NUMERIC,
    p_admin_name TEXT,
    p_payment_method TEXT DEFAULT 'cash',
    p_note TEXT DEFAULT ''
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    current_invoice RECORD;
    v_total_due NUMERIC;
    v_new_amount_paid NUMERIC;
    v_new_remaining NUMERIC;
    v_new_status public.invoice_status;
    new_entry JSONB;
    current_history JSONB;
BEGIN
    PERFORM public._assert_admin();

    SELECT * INTO current_invoice
    FROM public.invoices
    WHERE id = p_invoice_id AND public._tenant_visible(tenant_id)
    FOR UPDATE;

    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Tagihan tidak ditemukan'); END IF;
    IF current_invoice.status = 'paid' THEN RETURN jsonb_build_object('success', false, 'message', 'Tagihan sudah lunas'); END IF;
    IF p_payment_amount <= 0 THEN RETURN jsonb_build_object('success', false, 'message', 'Jumlah pembayaran harus lebih dari 0'); END IF;

    v_total_due := COALESCE(current_invoice.total_due, current_invoice.amount);
    v_new_amount_paid := COALESCE(current_invoice.amount_paid, 0) + p_payment_amount;
    v_new_remaining := v_total_due - v_new_amount_paid;

    IF v_new_remaining < 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Pembayaran melebihi sisa tagihan');
    END IF;

    IF v_new_remaining = 0 THEN v_new_status := 'paid'; ELSE v_new_status := 'partially_paid'; END IF;

    new_entry := jsonb_build_object(
        'payment_id', gen_random_uuid(),
        'amount', p_payment_amount,
        'paid_at', NOW(),
        'processed_by', p_admin_name,
        'payment_method', p_payment_method,
        'note', p_note,
        'remaining_after', v_new_remaining
    );

    current_history := COALESCE(current_invoice.payment_history, '[]'::jsonb) || jsonb_build_array(new_entry);

    UPDATE public.invoices
    SET amount_paid = v_new_amount_paid,
        status = v_new_status,
        last_payment_date = NOW(),
        paid_at = CASE WHEN v_new_status = 'paid' THEN NOW() ELSE paid_at END,
        payment_method = p_payment_method,
        payment_history = current_history
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Pembayaran berhasil diproses',
        'status', v_new_status,
        'amount_paid', v_new_amount_paid,
        'remaining_amount', v_new_remaining
    );
END;
$$;

-- 9.10. RPC Notifikasi (get_unread_notification_count, get_user_notifications, mark_notification_read)
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(user_id_param UUID)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    unread_count INTEGER;
    u_role TEXT;
    u_tenant UUID;
BEGIN
    IF NOT public.is_service_context() AND user_id_param IS DISTINCT FROM auth.uid() THEN RETURN 0; END IF;

    SELECT public.normalize_role(role), tenant_id INTO u_role, u_tenant
    FROM public.profiles WHERE id = user_id_param;

    SELECT COUNT(*)::INTEGER INTO unread_count
    FROM public.notifications n
    WHERE n.tenant_id IS NOT DISTINCT FROM u_tenant
      AND (n.recipient_user_id = user_id_param OR (public.normalize_role(n.recipient_role) = u_role AND n.recipient_user_id IS NULL))
      AND NOT EXISTS (
          SELECT 1 FROM public.notification_reads nr WHERE nr.notification_id = n.id AND nr.user_id = user_id_param
      );

    RETURN COALESCE(unread_count, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_notifications(user_id_param UUID DEFAULT NULL)
RETURNS TABLE(
    id UUID, title TEXT, body TEXT, url TEXT, created_at TIMESTAMPTZ, is_read BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    target_user UUID := COALESCE(user_id_param, auth.uid());
    u_role TEXT;
    u_tenant UUID;
BEGIN
    IF NOT public.is_service_context() AND target_user IS DISTINCT FROM auth.uid() THEN RETURN; END IF;

    SELECT public.normalize_role(p.role), p.tenant_id INTO u_role, u_tenant
    FROM public.profiles p WHERE p.id = target_user;

    RETURN QUERY
    SELECT
        n.id, n.title, n.body, n.url, n.created_at,
        EXISTS (
            SELECT 1 FROM public.notification_reads nr
            WHERE nr.notification_id = n.id AND nr.user_id = target_user
        ) AS is_read
    FROM public.notifications n
    WHERE n.tenant_id IS NOT DISTINCT FROM u_tenant
      AND (n.recipient_user_id = target_user OR (public.normalize_role(n.recipient_role) = u_role AND n.recipient_user_id IS NULL))
    ORDER BY n.created_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(
    notification_id_param UUID,
    user_id_param UUID
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF NOT public.is_service_context() AND user_id_param IS DISTINCT FROM auth.uid() THEN RETURN FALSE; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.notifications n
        JOIN public.profiles p ON p.id = user_id_param
        WHERE n.id = notification_id_param AND n.tenant_id IS NOT DISTINCT FROM p.tenant_id
    ) THEN
        RETURN FALSE;
    END IF;

    INSERT INTO public.notification_reads (notification_id, user_id, read_at)
    VALUES (notification_id_param, user_id_param, NOW())
    ON CONFLICT (notification_id, user_id) DO UPDATE SET read_at = NOW();
    RETURN TRUE;
END;
$$;

-- 9.11. RPC Helper Notifikasi Admin Tambahan
CREATE OR REPLACE FUNCTION public.send_admin_login_notification(admin_name TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, url)
    VALUES (public.get_my_tenant_id(), 'Admin Login', admin_name || ' telah login ke sistem.', 'ADMIN', '/dashboard.html');
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_customer_added_notification(admin_name TEXT, customer_name TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, url)
    VALUES (public.get_my_tenant_id(), 'Pelanggan Baru', customer_name || ' berhasil ditambahkan oleh ' || admin_name || '.', 'ADMIN', '/pelanggan.html');
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_invoice_creation_notification(admin_name TEXT, invoice_count INTEGER, period TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, url)
    VALUES (public.get_my_tenant_id(), 'Tagihan Dibuat', invoice_count || ' tagihan baru periode ' || period || ' berhasil dibuat oleh ' || admin_name || '.', 'ADMIN', '/tagihan.html');
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_payment_notification(
    customer_name TEXT, customer_idpl TEXT, invoice_period TEXT, amount NUMERIC, admin_name TEXT,
    customer_id UUID DEFAULT NULL, invoice_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    PERFORM public.add_payment_notification(customer_name, customer_idpl, invoice_period, amount, admin_name);
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_admin_activity(
    admin_id UUID, action TEXT, description TEXT, additional_data JSONB DEFAULT '{}'::jsonb, activity_timestamp TIMESTAMPTZ DEFAULT NOW()
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, type, data, created_at)
    VALUES (public.get_my_tenant_id(), action, description, 'ADMIN', 'activity_log', additional_data, activity_timestamp);
END;
$$;

-- 9.12. RPC Khusus Super Admin: get_superadmin_tenants()
-- Mengambil seluruh daftar tenant beserta info paket, kuota efektif, jumlah pelanggan terpakai, dan info owner
CREATE OR REPLACE FUNCTION public.get_superadmin_tenants()
RETURNS TABLE (
    id UUID,
    name VARCHAR(150),
    slug VARCHAR(100),
    owner_id UUID,
    owner_name TEXT,
    owner_email TEXT,
    plan_id UUID,
    plan_name VARCHAR(100),
    plan_slug VARCHAR(100),
    plan_max_customers INTEGER,
    custom_max_customers INTEGER,
    effective_max_customers INTEGER,
    used_customers INTEGER,
    subscription_status VARCHAR(20),
    subscription_expires_at TIMESTAMPTZ,
    company_address TEXT,
    company_phone VARCHAR(30),
    created_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
BEGIN
    IF NOT public.is_service_context() AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Akses ditolak: Hanya Super Admin yang dapat mengakses data ini.' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.slug,
        t.owner_id,
        COALESCE(p.full_name, 'Admin') AS owner_name,
        COALESCE(u.email::TEXT, '') AS owner_email,
        t.plan_id,
        COALESCE(sp.name, 'Tanpa Paket') AS plan_name,
        sp.slug AS plan_slug,
        sp.max_customers AS plan_max_customers,
        t.custom_max_customers,
        CASE 
            WHEN t.custom_max_customers = -1 THEN NULL
            WHEN t.custom_max_customers IS NOT NULL THEN t.custom_max_customers
            ELSE sp.max_customers
        END AS effective_max_customers,
        COALESCE(cust_count.total_active, 0)::INTEGER AS used_customers,
        t.subscription_status,
        t.subscription_expires_at,
        t.company_address,
        t.company_phone,
        t.created_at
    FROM public.tenants t
    LEFT JOIN public.saas_plans sp ON sp.id = t.plan_id
    LEFT JOIN public.profiles p ON p.id = t.owner_id
    LEFT JOIN auth.users u ON u.id = t.owner_id
    LEFT JOIN (
        SELECT prof.tenant_id, COUNT(*)::INTEGER AS total_active
        FROM public.profiles prof
        WHERE public.normalize_role(prof.role) = 'pelanggan'
          AND prof.status = 'AKTIF'
        GROUP BY prof.tenant_id
    ) cust_count ON cust_count.tenant_id = t.id
    ORDER BY t.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_superadmin_tenants() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_superadmin_tenants() TO authenticated, service_role;

-- 9.13. RPC Khusus Super Admin: update_tenant_by_superadmin()
CREATE OR REPLACE FUNCTION public.update_tenant_by_superadmin(
    p_tenant_id UUID,
    p_name TEXT,
    p_plan_id UUID,
    p_custom_max_customers INTEGER DEFAULT NULL,
    p_subscription_status TEXT DEFAULT 'active',
    p_subscription_expires_at TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF NOT public.is_service_context() AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Akses ditolak: Hanya Super Admin yang dapat mengubah data tenant.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.tenants
    SET 
        name = COALESCE(NULLIF(trim(p_name), ''), name),
        plan_id = p_plan_id,
        custom_max_customers = p_custom_max_customers,
        subscription_status = p_subscription_status,
        subscription_expires_at = p_subscription_expires_at,
        updated_at = NOW()
    WHERE id = p_tenant_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tenant tidak ditemukan');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Data tenant berhasil diperbarui');
END;
$$;

REVOKE ALL ON FUNCTION public.update_tenant_by_superadmin(UUID, TEXT, UUID, INTEGER, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_tenant_by_superadmin(UUID, TEXT, UUID, INTEGER, TEXT, TIMESTAMPTZ) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 10. SUPABASE STORAGE BUCKETS ('avatars' & 'tenant-assets')
-- ------------------------------------------------------------------------------

-- 10.1. Bucket avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars', 'avatars', TRUE, 5242880,
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

-- 10.2. Bucket tenant-assets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'tenant-assets', 'tenant-assets', TRUE, 5242880,
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml', 'image/x-icon']
)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

-- Storage Helper: validasi folder pertama path = tenant user
CREATE OR REPLACE FUNCTION public.storage_path_is_my_tenant(p_name TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, storage AS $$
DECLARE v_folder TEXT := (storage.foldername(p_name))[1];
BEGIN
    IF v_folder IS NULL OR v_folder !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN FALSE;
    END IF;
    RETURN v_folder::uuid = public.get_my_tenant_id();
END;
$$;

-- Storage Policies: avatars
DROP POLICY IF EXISTS "Avatar Public Access" ON storage.objects;
CREATE POLICY "Avatar Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated User Upload Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Upload Avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated User Update Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Update Avatar" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated User Delete Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Delete Avatar" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'avatars');

-- Storage Policies: tenant-assets
DROP POLICY IF EXISTS "tenant_assets_public_read" ON storage.objects;
CREATE POLICY "tenant_assets_public_read" ON storage.objects FOR SELECT USING (bucket_id = 'tenant-assets');

DROP POLICY IF EXISTS "tenant_assets_admin_insert" ON storage.objects;
CREATE POLICY "tenant_assets_admin_insert" ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'tenant-assets' AND (public.is_super_admin() OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))));

DROP POLICY IF EXISTS "tenant_assets_admin_update" ON storage.objects;
CREATE POLICY "tenant_assets_admin_update" ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'tenant-assets' AND (public.is_super_admin() OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))))
    WITH CHECK (bucket_id = 'tenant-assets' AND (public.is_super_admin() OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))));

DROP POLICY IF EXISTS "tenant_assets_admin_delete" ON storage.objects;
CREATE POLICY "tenant_assets_admin_delete" ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'tenant-assets' AND (public.is_super_admin() OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))));

-- ------------------------------------------------------------------------------
-- 11. DATA AWAL / INITIAL SEED DATA (Idempotent)
-- ------------------------------------------------------------------------------

-- 11.1. Seed SaaS Plans
INSERT INTO public.saas_plans (name, slug, price_monthly, max_customers, features, is_active) VALUES
    ('Free Trial', 'free-trial', 0, 25, '{"whatsapp_gateway": true, "genieacs": false, "custom_receipt": false, "trial_days": 14}'::jsonb, TRUE),
    ('Starter', 'starter', 10000, 100, '{"whatsapp_gateway": true, "genieacs": false, "custom_receipt": true}'::jsonb, TRUE),
    ('Pro', 'pro', 25000, 500, '{"whatsapp_gateway": true, "genieacs": true, "custom_receipt": true}'::jsonb, TRUE),
    ('Unlimited', 'unlimited', 50000, NULL, '{"whatsapp_gateway": true, "genieacs": true, "custom_receipt": true, "priority_support": true}'::jsonb, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- 11.2. Seed Default Tenant
INSERT INTO public.tenants (
    id, name, slug, plan_id, subscription_status, subscription_expires_at
)
VALUES (
    public.default_tenant_id(),
    'Rivamnet Default',
    'rivamnet-default',
    (SELECT id FROM public.saas_plans WHERE slug = 'unlimited' LIMIT 1),
    'active',
    NULL
)
ON CONFLICT (id) DO NOTHING;

-- 11.3. Default Packages untuk Default Tenant
INSERT INTO public.packages (id, tenant_id, package_name, price, speed_mbps, description) VALUES
(1, public.default_tenant_id(), 'Paket Hemat 10 Mbps', 100000, 10, 'Akses internet stabil untuk kebutuhan browsing & streaming ringan'),
(2, public.default_tenant_id(), 'Paket Super 20 Mbps', 150000, 20, 'Cocok untuk kebutuhan keluarga, belajar & bekerja dari rumah'),
(3, public.default_tenant_id(), 'Paket Ultra 50 Mbps', 250000, 50, 'Kecepatan tinggi untuk streaming 4K, gaming & multi device')
ON CONFLICT (id) DO NOTHING;
SELECT setval('public.packages_id_seq', (SELECT COALESCE(MAX(id), 1) FROM public.packages));

-- 11.4. Inisialisasi Default Settings untuk Default Tenant
SELECT public.init_tenant_defaults(public.default_tenant_id(), 'Rivamnet Default');

-- 11.5. Default Payment Methods untuk Default Tenant
INSERT INTO public.payment_methods (tenant_id, bank_name, account_number, account_holder, sort_order, is_active) VALUES
(public.default_tenant_id(), 'TUNAI (CASH)', 'LOKET-KASIR', 'KASIR REVAM NET', 1, TRUE),
(public.default_tenant_id(), 'BANK BCA', '1234567890', 'REVAM NET BILLING', 2, TRUE),
(public.default_tenant_id(), 'BANK BRI', '098765432112345', 'REVAM NET BILLING', 3, TRUE),
(public.default_tenant_id(), 'DANA / OVO / GOPAY', '081234567890', 'REVAM NET', 4, TRUE)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------------------
-- 12. ROW LEVEL SECURITY (RLS) & POLICIES MENYELURUH
-- ------------------------------------------------------------------------------

-- Aktifkan RLS di semua tabel
ALTER TABLE public.saas_plans         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packages           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.genieacs_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wifi_change_logs   ENABLE ROW LEVEL SECURITY;

-- 12.1. saas_plans
CREATE POLICY saas_plans_public_read ON public.saas_plans FOR SELECT TO anon, authenticated
    USING (is_active = TRUE OR (SELECT public.is_super_admin()));
CREATE POLICY saas_plans_super_admin_all ON public.saas_plans FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));

-- 12.2. tenants
CREATE POLICY tenants_super_admin_all ON public.tenants FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY tenants_admin_select ON public.tenants FOR SELECT TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND id = (SELECT public.get_my_tenant_id()));
CREATE POLICY tenants_admin_update ON public.tenants FOR UPDATE TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND id = (SELECT public.get_my_tenant_id()));

-- View Profil Publik Tenant untuk Pelanggan
CREATE OR REPLACE VIEW public.tenant_public_profile AS
SELECT t.id, t.name, t.slug, t.logo_url, t.qris_url, t.company_address, t.company_phone
FROM public.tenants t
WHERE t.id = public.get_my_tenant_id() OR public.is_super_admin();
GRANT SELECT ON public.tenant_public_profile TO authenticated;

-- 12.3. profiles
CREATE POLICY profiles_super_admin_all ON public.profiles FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY profiles_admin_tenant_all ON public.profiles FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY profiles_self_select ON public.profiles FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()));
CREATE POLICY profiles_self_update ON public.profiles FOR UPDATE TO authenticated
    USING (id = (SELECT auth.uid())) WITH CHECK (id = (SELECT auth.uid()));

-- 12.4. packages
CREATE POLICY packages_super_admin_all ON public.packages FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY packages_admin_tenant_all ON public.packages FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY packages_member_select ON public.packages FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()));

-- 12.5. invoices
CREATE POLICY invoices_super_admin_all ON public.invoices FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY invoices_admin_tenant_all ON public.invoices FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY invoices_customer_select_own ON public.invoices FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));

-- 12.6. expenses
CREATE POLICY expenses_super_admin_all ON public.expenses FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY expenses_admin_tenant_all ON public.expenses FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

-- 12.7. payment_methods
CREATE POLICY payment_methods_super_admin_all ON public.payment_methods FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY payment_methods_admin_tenant_all ON public.payment_methods FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY payment_methods_member_select ON public.payment_methods FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()));

-- 12.8. notifications & notification_reads
CREATE POLICY notifications_super_admin_all ON public.notifications FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY notifications_admin_tenant_all ON public.notifications FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY notifications_customer_select_own ON public.notifications FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()) AND (recipient_user_id = (SELECT auth.uid()) OR (recipient_user_id IS NULL AND public.normalize_role(recipient_role) = (SELECT public.get_my_role()))));
CREATE POLICY notifications_member_insert ON public.notifications FOR INSERT TO authenticated
    WITH CHECK (tenant_id = (SELECT public.get_my_tenant_id()));

CREATE POLICY notification_reads_own_all ON public.notification_reads FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- 12.9. app_settings
CREATE POLICY app_settings_super_admin_all ON public.app_settings FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY app_settings_admin_tenant_all ON public.app_settings FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY app_settings_member_select ON public.app_settings FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY app_settings_anon_default_branding ON public.app_settings FOR SELECT TO anon
    USING (tenant_id = public.default_tenant_id());

-- 12.10. whatsapp_settings (HANYA Admin Tenant)
CREATE POLICY whatsapp_settings_super_admin_all ON public.whatsapp_settings FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY whatsapp_settings_admin_tenant_all ON public.whatsapp_settings FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

-- 12.11. genieacs_settings (HANYA Admin Tenant)
CREATE POLICY genieacs_settings_super_admin_all ON public.genieacs_settings FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY genieacs_settings_admin_tenant_all ON public.genieacs_settings FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

CREATE OR REPLACE FUNCTION public.get_genieacs_status()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE((
        SELECT lower(setting_value) = 'true'
        FROM public.genieacs_settings
        WHERE tenant_id = public.get_my_tenant_id() AND setting_key = 'genieacs_enabled'
        LIMIT 1
    ), FALSE);
$$;
GRANT EXECUTE ON FUNCTION public.get_genieacs_status() TO authenticated;

-- 12.12. wifi_change_logs
CREATE POLICY wifi_logs_super_admin_all ON public.wifi_change_logs FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin())) WITH CHECK ((SELECT public.is_super_admin()));
CREATE POLICY wifi_logs_admin_tenant_all ON public.wifi_change_logs FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));
CREATE POLICY wifi_logs_customer_select_own ON public.wifi_change_logs FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));
CREATE POLICY wifi_logs_customer_insert_own ON public.wifi_change_logs FOR INSERT TO authenticated
    WITH CHECK (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));
CREATE POLICY wifi_logs_customer_update_own ON public.wifi_change_logs FOR UPDATE TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()))
    WITH CHECK (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));

-- ------------------------------------------------------------------------------
-- 13. HAK AKSES SKEMA & TABEL (GRANTS)
-- ------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

GRANT SELECT ON public.saas_plans TO anon, authenticated;
GRANT SELECT, UPDATE ON public.tenants TO authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.packages TO authenticated;
GRANT ALL ON public.invoices TO authenticated;
GRANT ALL ON public.expenses TO authenticated;
GRANT ALL ON public.payment_methods TO authenticated;
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.notification_reads TO authenticated;
GRANT ALL ON public.app_settings TO authenticated;
GRANT SELECT ON public.app_settings TO anon;
GRANT ALL ON public.whatsapp_settings TO authenticated;
GRANT ALL ON public.genieacs_settings TO authenticated;
GRANT ALL ON public.wifi_change_logs TO authenticated;

GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

-- 9.14. RPC Khusus Super Admin: delete_tenant_by_superadmin()
CREATE OR REPLACE FUNCTION public.delete_tenant_by_superadmin(p_tenant_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
    v_owner_id UUID;
    v_name TEXT;
BEGIN
    IF NOT public.is_service_context() AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Akses ditolak: Hanya Super Admin yang dapat menghapus tenant.' USING ERRCODE = '42501';
    END IF;

    IF p_tenant_id = 'a0000000-0000-4000-8000-000000000001'::uuid OR p_tenant_id = public.default_tenant_id() THEN
        RAISE EXCEPTION 'Tenant default sistem tidak dapat dihapus.' USING ERRCODE = '42501';
    END IF;

    SELECT name, owner_id INTO v_name, v_owner_id FROM public.tenants WHERE id = p_tenant_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tenant tidak ditemukan.');
    END IF;

    -- Hapus tenant (cascade akan menghapus seluruh data operasional di profiles, invoices, packages, dll)
    DELETE FROM public.tenants WHERE id = p_tenant_id;

    -- Hapus akun auth owner jika ada
    IF v_owner_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_owner_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Mitra ' || v_name || ' berhasil dihapus beserta seluruh datanya.');
END;
$$;

REVOKE ALL ON FUNCTION public.delete_tenant_by_superadmin(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_tenant_by_superadmin(UUID) TO authenticated, service_role;

SELECT 'SaaS Multi-Tenant Master Database schema, tables, functions, triggers, storage, and policies setup successfully!' AS result;


-- ==============================================================================
-- FASE 10: Otomatisasi Penghapusan Akun Auth Saat Tenant Dihapus
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cascade_delete_tenant_auth_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    DELETE FROM auth.users
    WHERE id IN (
        SELECT p.id FROM public.profiles p WHERE p.tenant_id = OLD.id
    );

    IF OLD.owner_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = OLD.owner_id;
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trigger_cascade_delete_tenant_auth_users ON public.tenants;
CREATE TRIGGER trigger_cascade_delete_tenant_auth_users
    BEFORE DELETE ON public.tenants
    FOR EACH ROW
    EXECUTE FUNCTION public.cascade_delete_tenant_auth_users();

CREATE OR REPLACE FUNCTION public.delete_tenant_by_superadmin(p_tenant_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
    v_owner_id UUID;
    v_name TEXT;
BEGIN
    IF NOT public.is_service_context() AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Akses ditolak: Hanya Super Admin yang dapat menghapus tenant.' USING ERRCODE = '42501';
    END IF;

    IF p_tenant_id = 'a0000000-0000-4000-8000-000000000001'::uuid OR p_tenant_id = public.default_tenant_id() THEN
        RAISE EXCEPTION 'Tenant default sistem tidak dapat dihapus.' USING ERRCODE = '42501';
    END IF;

    SELECT name, owner_id INTO v_name, v_owner_id FROM public.tenants WHERE id = p_tenant_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tenant tidak ditemukan.');
    END IF;

    DELETE FROM auth.users WHERE id IN (
        SELECT id FROM public.profiles WHERE tenant_id = p_tenant_id
    );

    IF v_owner_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_owner_id;
    END IF;

    DELETE FROM public.tenants WHERE id = p_tenant_id;

    RETURN jsonb_build_object('success', true, 'message', 'Mitra "' || v_name || '" berhasil dihapus beserta seluruh akun Auth dan datanya.');
END;
$$;

CREATE OR REPLACE FUNCTION public.cleanup_orphan_auth_user(p_email TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NOT public.is_service_context() AND NOT public.is_super_admin() THEN
        RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
    END IF;

    DELETE FROM auth.users WHERE lower(email) = lower(trim(p_email));
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object('success', true, 'deleted_count', v_count);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_tenant_by_superadmin(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_tenant_by_superadmin(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cleanup_orphan_auth_user(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_orphan_auth_user(TEXT) TO authenticated, service_role;


-- ==============================================================================
-- FASE 11: Fix Trigger handle_new_user (Mencegah Pelanggan Menjadi Tenant)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_full_name   TEXT := COALESCE(NEW.raw_user_meta_data ->> 'full_name', '');
    v_phone       TEXT := NULLIF(trim(COALESCE(NEW.raw_user_meta_data ->> 'phone', NEW.raw_user_meta_data ->> 'whatsapp_number')), '');
    v_tenant_id   UUID;
    v_role        TEXT;
    v_user_type   TEXT;
    v_company     TEXT;
    v_plan_id     UUID;
    v_plan_raw    TEXT;
    v_plan_slug   TEXT;
    v_trial_days  INTEGER;
    v_is_customer BOOLEAN := FALSE;
BEGIN
    -- Ambil tenant_id dari app_metadata atau user_metadata
    BEGIN
        v_tenant_id := NULLIF(COALESCE(
            NEW.raw_app_meta_data ->> 'tenant_id',
            NEW.raw_user_meta_data ->> 'tenant_id'
        ), '')::uuid;
    EXCEPTION WHEN others THEN
        v_tenant_id := NULL;
    END;

    v_user_type := lower(COALESCE(
        NEW.raw_app_meta_data ->> 'user_type',
        NEW.raw_user_meta_data ->> 'user_type',
        ''
    ));
    
    v_role := public.normalize_role(COALESCE(
        NEW.raw_app_meta_data ->> 'role',
        NEW.raw_user_meta_data ->> 'role',
        ''
    ));

    IF v_user_type = 'customer' OR v_role = 'pelanggan' THEN
        v_is_customer := TRUE;
    END IF;

    IF v_tenant_id IS NOT NULL OR v_is_customer THEN
        -- ===================== SKENARIO B: Pelanggan / Anggota Tenant =====================
        IF v_tenant_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_tenant_id) THEN
            v_tenant_id := public.default_tenant_id();
        END IF;

        v_role := CASE
            WHEN v_role = 'admin' THEN 'ADMIN'
            ELSE 'USER'
        END;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id, whatsapp_number)
        VALUES (NEW.id, v_full_name, v_role, 'AKTIF', 'assets/avatar_male.svg', v_tenant_id, v_phone)
        ON CONFLICT (id) DO UPDATE SET
            full_name       = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
            role            = EXCLUDED.role,
            tenant_id       = EXCLUDED.tenant_id,
            whatsapp_number = COALESCE(EXCLUDED.whatsapp_number, public.profiles.whatsapp_number);
    ELSE
        -- ===================== SKENARIO A: Calon Mitra Baru (Pendaftaran SaaS) =====================
        v_company := COALESCE(
            NULLIF(trim(NEW.raw_user_meta_data ->> 'company_name'), ''),
            NULLIF(trim(v_full_name), ''),
            split_part(COALESCE(NEW.email, 'tenant'), '@', 1)
        );

        -- Ambil paket dari metadata (plan_slug atau plan_name)
        v_plan_raw := lower(trim(COALESCE(
            NEW.raw_user_meta_data ->> 'plan_slug',
            NEW.raw_user_meta_data ->> 'plan_name',
            'free-trial'
        )));

        -- Normalisasi slug paket
        IF v_plan_raw LIKE '%starter%' THEN
            v_plan_slug := 'starter';
        ELSIF v_plan_raw LIKE '%pro%' THEN
            v_plan_slug := 'pro';
        ELSIF v_plan_raw LIKE '%unlimited%' THEN
            v_plan_slug := 'unlimited';
        ELSE
            v_plan_slug := 'free-trial';
        END IF;

        -- Cari plan_id di saas_plans
        SELECT id, COALESCE((features ->> 'trial_days')::int, 14)
          INTO v_plan_id, v_trial_days
        FROM public.saas_plans
        WHERE slug = v_plan_slug OR lower(name) = v_plan_slug
        LIMIT 1;

        -- Fallback ke free-trial jika tidak ditemukan
        IF v_plan_id IS NULL THEN
            SELECT id, COALESCE((features ->> 'trial_days')::int, 14)
              INTO v_plan_id, v_trial_days
            FROM public.saas_plans
            WHERE slug = 'free-trial'
            LIMIT 1;
        END IF;

        INSERT INTO public.tenants (
            name, slug, owner_id, plan_id, subscription_status, subscription_expires_at, company_phone
        ) VALUES (
            v_company,
            public.generate_tenant_slug(v_company),
            NEW.id,
            v_plan_id,
            'trial',
            NOW() + make_interval(days => COALESCE(v_trial_days, 14)),
            v_phone
        )
        RETURNING id INTO v_tenant_id;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id, whatsapp_number)
        VALUES (NEW.id, v_full_name, 'ADMIN', 'AKTIF', 'assets/avatar_male.svg', v_tenant_id, v_phone)
        ON CONFLICT (id) DO UPDATE SET
            full_name       = EXCLUDED.full_name,
            role            = 'ADMIN',
            tenant_id       = EXCLUDED.tenant_id,
            whatsapp_number = COALESCE(EXCLUDED.whatsapp_number, public.profiles.whatsapp_number);

        PERFORM public.init_tenant_defaults(v_tenant_id, v_company);
    END IF;

    RETURN NEW;
END;

        PERFORM public.init_tenant_defaults(v_tenant_id, v_company);
    END IF;

    RETURN NEW;
END;
$$;


-- ==============================================================================
-- FASE 12: Fix RPC get_dashboard_charts_data (Chart Dashboard Multi-Tenant)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.get_dashboard_charts_data(p_months INTEGER DEFAULT 6)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    labels_data JSONB := '[]'::jsonb;
    revenue_data JSONB := '[]'::jsonb;
    expenses_data JSONB := '[]'::jsonb;
    profit_data JSONB := '[]'::jsonb;
    customer_growth_new JSONB := '[]'::jsonb;
    customer_growth_churn JSONB := '[]'::jsonb;
    customer_total_data JSONB := '[]'::jsonb;
    
    start_date DATE;
    month_cursor DATE;
    m_name TEXT;
    m_num INTEGER;
    y_num INTEGER;
    m_start TIMESTAMPTZ;
    m_end TIMESTAMPTZ;
    
    rev NUMERIC;
    exp NUMERIC;
    new_cust INTEGER;
    churn_cust INTEGER;
    cum_active INTEGER;
    
    paid_count INTEGER := 0;
    partially_paid_count INTEGER := 0;
    unpaid_count INTEGER := 0;
    total_inv INTEGER := 0;
BEGIN
    PERFORM public._assert_admin();

    start_date := (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL)::DATE;

    FOR i IN 0..(p_months - 1) LOOP
        month_cursor := (start_date + (i || ' months')::INTERVAL)::DATE;
        m_num := EXTRACT(MONTH FROM month_cursor)::INTEGER;
        y_num := EXTRACT(YEAR FROM month_cursor)::INTEGER;
        m_start := DATE_TRUNC('month', month_cursor);
        m_end := (m_start + INTERVAL '1 month');

        SELECT CASE m_num
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Agu' WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Okt' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Des'
        END INTO m_name;

        labels_data := labels_data || to_jsonb(m_name || ' ' || y_num);

        SELECT COALESCE(SUM(amount_paid), 0) INTO rev
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id)
          AND (
              (last_payment_date >= m_start AND last_payment_date < m_end)
              OR (last_payment_date IS NULL AND paid_at >= m_start AND paid_at < m_end)
              OR (last_payment_date IS NULL AND paid_at IS NULL AND created_at >= m_start AND created_at < m_end AND status = 'paid')
          );

        IF rev = 0 THEN
            SELECT COALESCE(SUM(amount_paid), 0) INTO rev
            FROM public.invoices
            WHERE public._tenant_visible(tenant_id)
              AND status IN ('paid', 'partially_paid')
              AND created_at >= m_start AND created_at < m_end;
        END IF;

        revenue_data := revenue_data || to_jsonb(rev);

        SELECT COALESCE(SUM(amount), 0) INTO exp
        FROM public.expenses
        WHERE public._tenant_visible(tenant_id)
          AND expense_date >= month_cursor 
          AND expense_date < (month_cursor + INTERVAL '1 month')::DATE;

        expenses_data := expenses_data || to_jsonb(exp);
        profit_data := profit_data || to_jsonb(rev - exp);

        SELECT COUNT(*)::INTEGER INTO new_cust
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND (
              (installation_date >= month_cursor AND installation_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (installation_date IS NULL AND created_at >= m_start AND created_at < m_end)
          );
        customer_growth_new := customer_growth_new || to_jsonb(new_cust);

        SELECT COUNT(*)::INTEGER INTO churn_cust
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND status = 'NONAKTIF'
          AND (
              (churn_date >= month_cursor AND churn_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (churn_date IS NULL AND updated_at >= m_start AND updated_at < m_end)
          );
        customer_growth_churn := customer_growth_churn || to_jsonb(churn_cust);

        SELECT COUNT(*)::INTEGER INTO cum_active
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND status = 'AKTIF'
          AND created_at < m_end;
        customer_total_data := customer_total_data || to_jsonb(cum_active);

    END LOOP;

    SELECT 
        COUNT(CASE WHEN status = 'paid' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status = 'partially_paid' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END)::INTEGER
    INTO paid_count, partially_paid_count, unpaid_count
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE);

    total_inv := paid_count + partially_paid_count + unpaid_count;
    IF total_inv = 0 THEN
        SELECT 
            COUNT(CASE WHEN status = 'paid' THEN 1 END)::INTEGER,
            COUNT(CASE WHEN status = 'partially_paid' THEN 1 END)::INTEGER,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END)::INTEGER
        INTO paid_count, partially_paid_count, unpaid_count
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id);
    END IF;

    RETURN jsonb_build_object(
        'revenue_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Pendapatan',
                    'data', revenue_data,
                    'borderColor', '#10B981',
                    'backgroundColor', 'rgba(16, 185, 129, 0.1)',
                    'tension', 0.4,
                    'fill', true
                ),
                jsonb_build_object(
                    'label', 'Pengeluaran',
                    'data', expenses_data,
                    'borderColor', '#EF4444',
                    'backgroundColor', 'rgba(239, 68, 68, 0.1)',
                    'tension', 0.4,
                    'fill', true
                ),
                jsonb_build_object(
                    'label', 'Profit',
                    'data', profit_data,
                    'borderColor', '#6366F1',
                    'backgroundColor', 'rgba(99, 102, 241, 0.1)',
                    'tension', 0.4,
                    'fill', true
                )
            )
        ),
        'payment_status_chart', jsonb_build_object(
            'labels', jsonb_build_array('Lunas', 'Cicilan', 'Belum Bayar'),
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'data', jsonb_build_array(paid_count, partially_paid_count, unpaid_count),
                    'backgroundColor', jsonb_build_array('#10B981', '#F59E0B', '#EF4444'),
                    'borderColor', jsonb_build_array('#059669', '#D97706', '#DC2626'),
                    'borderWidth', 2
                )
            )
        ),
        'customer_growth_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Pelanggan Baru',
                    'data', customer_growth_new,
                    'backgroundColor', '#10B981',
                    'borderColor', '#059669',
                    'borderWidth', 2,
                    'borderRadius', 4
                ),
                jsonb_build_object(
                    'label', 'Pelanggan Berhenti',
                    'data', customer_growth_churn,
                    'backgroundColor', '#EF4444',
                    'borderColor', '#DC2626',
                    'borderWidth', 2,
                    'borderRadius', 4
                )
            )
        ),
        'customer_total_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Total Pelanggan Aktif',
                    'data', customer_total_data,
                    'borderColor', '#8B5CF6',
                    'backgroundColor', 'rgba(139, 92, 246, 0.1)',
                    'tension', 0.4,
                    'fill', true
                )
            )
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dashboard_charts_data(INTEGER) TO authenticated, service_role;


-- ==============================================================================
-- FASE 13: Fungsi Generator ID Pelanggan Acak 5 Karakter (2 Huruf + 3 Angka)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.generate_customer_idpl(p_tenant_id UUID DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant UUID := COALESCE(p_tenant_id, public.get_my_tenant_id());
    v_letters TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    v_idpl TEXT;
    v_exists BOOLEAN;
    v_l1 CHAR(1);
    v_l2 CHAR(1);
    v_num INTEGER;
BEGIN
    LOOP
        v_l1 := substr(v_letters, floor(random() * length(v_letters) + 1)::int, 1);
        v_l2 := substr(v_letters, floor(random() * length(v_letters) + 1)::int, 1);
        v_num := floor(random() * 1000)::int;
        v_idpl := v_l1 || v_l2 || lpad(v_num::text, 3, '0');

        SELECT EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE idpl = v_idpl 
              AND (v_tenant IS NULL OR tenant_id = v_tenant)
        ) INTO v_exists;

        EXIT WHEN NOT v_exists;
    END LOOP;

    RETURN v_idpl;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_customer_idpl(UUID) TO authenticated, service_role;
-- ==============================================================================
-- FASE 14: Tenant Branding by Slug RPC (Halaman Login & PWA Multi-Tenant)
-- ==============================================================================
-- Fungsi ini memungkinkan pengunjung publik (anonim) yang membuka link dengan
-- parameter slug (misal: index.html?t=apik atau index.html?t=selinggonet)
-- untuk memuat logo, nama usaha, tema, dan ikon PWA milik tenant terkait.
-- 
-- Aman & Terisolasi: Hanya mengekspos properti visual publik (nama, logo, warna).
-- Tidak mengekspos token, password, data pelanggan, atau tagihan.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_tenant_branding_by_slug(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean_slug TEXT := lower(trim(p_slug));
    v_tenant RECORD;
    v_settings RECORD;
    v_logo TEXT;
    v_name TEXT;
BEGIN
    IF v_clean_slug IS NULL OR v_clean_slug = '' THEN
        RETURN NULL;
    END IF;

    -- Cari tenant berdasarkan slug (exact match, awalan slug, atau kesamaan nama)
    SELECT id, name, slug, logo_url, qris_url
    INTO v_tenant
    FROM public.tenants
    WHERE lower(slug) = v_clean_slug
       OR lower(slug) LIKE v_clean_slug || '-%'
       OR lower(slug) LIKE v_clean_slug || '%'
       OR lower(name) = v_clean_slug
    ORDER BY
        CASE 
            WHEN lower(slug) = v_clean_slug THEN 1
            WHEN lower(slug) LIKE v_clean_slug || '-%' THEN 2
            WHEN lower(slug) LIKE v_clean_slug || '%' THEN 3
            ELSE 4
        END
    LIMIT 1;

    IF v_tenant.id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Ambil app_settings milik tenant tersebut
    SELECT *
    INTO v_settings
    FROM public.app_settings
    WHERE tenant_id = v_tenant.id
    LIMIT 1;

    v_name := COALESCE(NULLIF(trim(v_settings.app_name), ''), NULLIF(trim(v_tenant.name), ''), 'WiFi Billing');
    v_logo := COALESCE(NULLIF(trim(v_settings.logo_url), ''), NULLIF(trim(v_tenant.logo_url), ''), 'assets/logo_wifi.png');

    RETURN jsonb_build_object(
        'found', TRUE,
        'tenant_id', v_tenant.id,
        'tenant_name', v_tenant.name,
        'slug', v_tenant.slug,
        'app_name', v_name,
        'app_short_name', COALESCE(NULLIF(trim(v_settings.app_short_name), ''), left(v_name, 12)),
        'app_description', COALESCE(v_settings.app_description, 'Sistem Manajemen Billing & Pelanggan'),
        'app_tagline', COALESCE(v_settings.app_tagline, 'Internet Cepat & Tanpa Batas'),
        'logo_url', v_logo,
        'favicon_url', COALESCE(NULLIF(trim(v_settings.favicon_url), ''), v_logo),
        'icon_192_url', COALESCE(NULLIF(trim(v_settings.icon_192_url), ''), v_logo, 'assets/logo_192x192.png'),
        'icon_512_url', COALESCE(NULLIF(trim(v_settings.icon_512_url), ''), v_logo, 'assets/logo_512x512.png'),
        'theme_color', COALESCE(v_settings.theme_color, '#683fe4'),
        'background_color', COALESCE(v_settings.background_color, '#f9f8fc')
    );
END;
$$;

-- Berikan izin eksekusi ke anon, authenticated, dan service_role
REVOKE ALL ON FUNCTION public.get_tenant_branding_by_slug(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_tenant_branding_by_slug(TEXT) TO anon, authenticated, service_role;


-- ==============================================================================
-- FASE 15: Fix get_dashboard_charts_data (Fix missing column updated_at & installation_date)
-- ==============================================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE OR REPLACE FUNCTION public.get_dashboard_charts_data(p_months INTEGER DEFAULT 6)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    labels_data JSONB := '[]'::jsonb;
    revenue_data JSONB := '[]'::jsonb;
    expenses_data JSONB := '[]'::jsonb;
    profit_data JSONB := '[]'::jsonb;
    customer_growth_new JSONB := '[]'::jsonb;
    customer_growth_churn JSONB := '[]'::jsonb;
    customer_total_data JSONB := '[]'::jsonb;
    
    start_date DATE;
    month_cursor DATE;
    m_name TEXT;
    m_num INTEGER;
    y_num INTEGER;
    m_start TIMESTAMPTZ;
    m_end TIMESTAMPTZ;
    
    rev NUMERIC;
    exp NUMERIC;
    new_cust INTEGER;
    churn_cust INTEGER;
    cum_active INTEGER;
    
    paid_count INTEGER := 0;
    partially_paid_count INTEGER := 0;
    unpaid_count INTEGER := 0;
    total_inv INTEGER := 0;
BEGIN
    PERFORM public._assert_admin();

    start_date := (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL)::DATE;

    FOR i IN 0..(p_months - 1) LOOP
        month_cursor := (start_date + (i || ' months')::INTERVAL)::DATE;
        m_num := EXTRACT(MONTH FROM month_cursor)::INTEGER;
        y_num := EXTRACT(YEAR FROM month_cursor)::INTEGER;
        m_start := DATE_TRUNC('month', month_cursor);
        m_end := (m_start + INTERVAL '1 month');

        SELECT CASE m_num
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Agu' WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Okt' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Des'
        END INTO m_name;

        labels_data := labels_data || to_jsonb(m_name || ' ' || y_num);

        -- 1. Pendapatan (invoices milik tenant)
        SELECT COALESCE(SUM(amount_paid), 0) INTO rev
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id)
          AND (
              (last_payment_date >= m_start AND last_payment_date < m_end)
              OR (last_payment_date IS NULL AND paid_at >= m_start AND paid_at < m_end)
              OR (last_payment_date IS NULL AND paid_at IS NULL AND created_at >= m_start AND created_at < m_end AND status = 'paid')
          );

        IF rev = 0 THEN
            SELECT COALESCE(SUM(amount_paid), 0) INTO rev
            FROM public.invoices
            WHERE public._tenant_visible(tenant_id)
              AND status IN ('paid', 'partially_paid')
              AND created_at >= m_start AND created_at < m_end;
        END IF;

        revenue_data := revenue_data || to_jsonb(rev);

        -- 2. Pengeluaran (expenses milik tenant)
        SELECT COALESCE(SUM(amount), 0) INTO exp
        FROM public.expenses
        WHERE public._tenant_visible(tenant_id)
          AND expense_date >= month_cursor 
          AND expense_date < (month_cursor + INTERVAL '1 month')::DATE;

        expenses_data := expenses_data || to_jsonb(exp);
        profit_data := profit_data || to_jsonb(rev - exp);

        -- 3. Pertumbuhan Pelanggan Baru & Berhenti di bulan ini
        SELECT COUNT(*)::INTEGER INTO new_cust
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND (
              (installation_date >= month_cursor AND installation_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (installation_date IS NULL AND created_at >= m_start AND created_at < m_end)
          );
        customer_growth_new := customer_growth_new || to_jsonb(new_cust);

        SELECT COUNT(*)::INTEGER INTO churn_cust
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND status = 'NONAKTIF'
          AND (
              (churn_date >= month_cursor AND churn_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (churn_date IS NULL AND created_at >= m_start AND created_at < m_end)
          );
        customer_growth_churn := customer_growth_churn || to_jsonb(churn_cust);

        -- 4. Total Pelanggan Aktif Kumulatif sampai akhir bulan ini
        SELECT COUNT(*)::INTEGER INTO cum_active
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND status = 'AKTIF'
          AND (
              (installation_date IS NOT NULL AND installation_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (installation_date IS NULL AND created_at < m_end)
          );
        customer_total_data := customer_total_data || to_jsonb(cum_active);

    END LOOP;

    -- 5. Status Pembayaran Bulan Ini (atau keseluruhan tagihan jika bulan ini belum ada)
    SELECT 
        COUNT(CASE WHEN status = 'paid' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status = 'partially_paid' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END)::INTEGER
    INTO paid_count, partially_paid_count, unpaid_count
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE);

    total_inv := paid_count + partially_paid_count + unpaid_count;
    IF total_inv = 0 THEN
        SELECT 
            COUNT(CASE WHEN status = 'paid' THEN 1 END)::INTEGER,
            COUNT(CASE WHEN status = 'partially_paid' THEN 1 END)::INTEGER,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END)::INTEGER
        INTO paid_count, partially_paid_count, unpaid_count
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id);
    END IF;

    RETURN jsonb_build_object(
        'revenue_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Pendapatan',
                    'data', revenue_data,
                    'borderColor', '#10B981',
                    'backgroundColor', 'rgba(16, 185, 129, 0.1)',
                    'tension', 0.4,
                    'fill', true
                ),
                jsonb_build_object(
                    'label', 'Pengeluaran',
                    'data', expenses_data,
                    'borderColor', '#EF4444',
                    'backgroundColor', 'rgba(239, 68, 68, 0.1)',
                    'tension', 0.4,
                    'fill', true
                ),
                jsonb_build_object(
                    'label', 'Profit',
                    'data', profit_data,
                    'borderColor', '#6366F1',
                    'backgroundColor', 'rgba(99, 102, 241, 0.1)',
                    'tension', 0.4,
                    'fill', true
                )
            )
        ),
        'payment_status_chart', jsonb_build_object(
            'labels', jsonb_build_array('Lunas', 'Cicilan', 'Belum Bayar'),
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'data', jsonb_build_array(paid_count, partially_paid_count, unpaid_count),
                    'backgroundColor', jsonb_build_array('#10B981', '#F59E0B', '#EF4444'),
                    'borderColor', jsonb_build_array('#059669', '#D97706', '#DC2626'),
                    'borderWidth', 2
                )
            )
        ),
        'customer_growth_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Pelanggan Baru',
                    'data', customer_growth_new,
                    'backgroundColor', '#10B981',
                    'borderColor', '#059669',
                    'borderWidth', 2,
                    'borderRadius', 4
                ),
                jsonb_build_object(
                    'label', 'Pelanggan Berhenti',
                    'data', customer_growth_churn,
                    'backgroundColor', '#EF4444',
                    'borderColor', '#DC2626',
                    'borderWidth', 2,
                    'borderRadius', 4
                )
            )
        ),
        'customer_total_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Total Pelanggan Aktif',
                    'data', customer_total_data,
                    'borderColor', '#8B5CF6',
                    'backgroundColor', 'rgba(139, 92, 246, 0.1)',
                    'tension', 0.4,
                    'fill', true
                )
            )
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dashboard_charts_data(INTEGER) TO authenticated, service_role;
