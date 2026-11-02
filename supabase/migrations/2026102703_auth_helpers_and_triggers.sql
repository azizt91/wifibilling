-- ==============================================================================
-- FASE 3: Fungsi Helper Auth, Role, & Trigger Otomatis
-- ==============================================================================
-- STANDARISASI ROLE
--   Nilai yang disimpan di profiles.role tetap memakai format lama (uppercase)
--   agar frontend (login.js, auth.js, dsb.) tidak rusak:
--       'SUPER_ADMIN' -> super_admin  (pemilik platform SaaS)
--       'ADMIN'       -> admin        (pemilik / pengelola RT-RW Net)
--       'USER'        -> pelanggan    (pelanggan WiFi akhir)
--   public.normalize_role() memetakan seluruh variasi (ADMIN/admin/tenant_admin,
--   USER/pelanggan/customer, dst.) ke 3 role kanonik lowercase.
--   Di JWT (auth.users.raw_app_meta_data) role disimpan dalam bentuk kanonik.
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Normalisasi Role
-- ------------------------------------------------------------------------------
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

-- Kebalikan: role kanonik -> nilai yang disimpan di profiles.role
CREATE OR REPLACE FUNCTION public.role_to_storage(p_role TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE public.normalize_role(p_role)
        WHEN 'super_admin' THEN 'SUPER_ADMIN'
        WHEN 'admin' THEN 'ADMIN'
        ELSE 'USER'
    END;
$$;

-- ------------------------------------------------------------------------------
-- 2. Fungsi Helper RLS (SECURITY DEFINER, STABLE)
-- ------------------------------------------------------------------------------

-- 2.1 Tenant milik user yang sedang login (JWT app_metadata -> fallback profiles)
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

-- Alias sesuai guardrail rencana migrasi
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT public.get_my_tenant_id();
$$;

-- 2.2 Role (kanonik) milik user yang sedang login.
--     Sumber kebenaran: tabel profiles (agar perubahan role langsung berlaku),
--     fallback ke JWT app_metadata.
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

-- 2.3 Super admin?
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(public.get_my_role() = 'super_admin', FALSE);
$$;

-- 2.4 Admin tenant?
CREATE OR REPLACE FUNCTION public.is_tenant_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(public.get_my_role() = 'admin', FALSE);
$$;

-- 2.5 Langganan tenant masih aktif?
CREATE OR REPLACE FUNCTION public.is_tenant_active(check_tenant_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((
        SELECT t.subscription_status IN ('active', 'trial')
               AND (t.subscription_expires_at IS NULL OR t.subscription_expires_at > NOW())
        FROM public.tenants t
        WHERE t.id = check_tenant_id
    ), FALSE);
$$;

-- 2.6 Konteks "server" (service_role / cron / SQL editor / trigger auth) = tanpa JWT user
CREATE OR REPLACE FUNCTION public.is_service_context()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT auth.uid() IS NULL
        OR COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
$$;

-- Kompatibilitas: get_user_role() lama tetap ada (dipakai policy & frontend lama)
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    RETURN COALESCE(user_role, 'USER');
END;
$$;

GRANT EXECUTE ON FUNCTION
    public.normalize_role(TEXT),
    public.role_to_storage(TEXT),
    public.get_my_tenant_id(),
    public.current_tenant_id(),
    public.get_my_role(),
    public.is_super_admin(),
    public.is_tenant_admin(),
    public.is_tenant_active(UUID),
    public.is_service_context(),
    public.default_tenant_id()
TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. Default value tenant_id = get_my_tenant_id() pada tabel operasional
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    t TEXT;
    tables TEXT[] := ARRAY[
        'packages', 'invoices', 'expenses', 'payment_methods', 'notifications',
        'app_settings', 'whatsapp_settings', 'genieacs_settings', 'wifi_change_logs'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF to_regclass('public.' || t) IS NOT NULL THEN
            EXECUTE format(
                'ALTER TABLE public.%I ALTER COLUMN tenant_id SET DEFAULT public.get_my_tenant_id()', t);
        END IF;
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------
-- 4. Trigger turunan tenant_id dari parent (konsistensi lintas tabel)
--    - invoices / wifi_change_logs : selalu ikut tenant milik customer_id
--    - notifications               : ikut tenant recipient_user_id bila kosong
--    Trigger BEFORE berjalan sebelum WITH CHECK RLS, sehingga admin Tenant A
--    yang mencoba membuat tagihan untuk pelanggan Tenant B otomatis ditolak RLS.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_tenant_from_customer()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant UUID;
BEGIN
    IF NEW.customer_id IS NOT NULL THEN
        SELECT tenant_id INTO v_tenant FROM public.profiles WHERE id = NEW.customer_id;
        IF v_tenant IS NOT NULL THEN
            NEW.tenant_id := v_tenant;
        END IF;
    END IF;
    IF NEW.tenant_id IS NULL THEN
        NEW.tenant_id := public.get_my_tenant_id();
    END IF;
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

CREATE OR REPLACE FUNCTION public.set_tenant_from_recipient()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.tenant_id IS NULL AND NEW.recipient_user_id IS NOT NULL THEN
        SELECT tenant_id INTO NEW.tenant_id FROM public.profiles WHERE id = NEW.recipient_user_id;
    END IF;
    IF NEW.tenant_id IS NULL THEN
        NEW.tenant_id := public.get_my_tenant_id();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notifications_set_tenant ON public.notifications;
CREATE TRIGGER notifications_set_tenant
    BEFORE INSERT ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.set_tenant_from_recipient();

-- ------------------------------------------------------------------------------
-- 5. Sinkronisasi profiles.role / tenant_id -> auth.users.raw_app_meta_data (JWT)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_profile_claims_to_auth()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
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

-- Backfill klaim JWT untuk seluruh user yang sudah ada
UPDATE auth.users u
SET raw_app_meta_data = COALESCE(u.raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('tenant_id', p.tenant_id, 'role', public.normalize_role(p.role))
FROM public.profiles p
WHERE p.id = u.id
  AND (
      u.raw_app_meta_data ->> 'tenant_id' IS DISTINCT FROM p.tenant_id::text
      OR u.raw_app_meta_data ->> 'role' IS DISTINCT FROM public.normalize_role(p.role)
  );

-- ------------------------------------------------------------------------------
-- 6. Inisialisasi konfigurasi default untuk tenant baru
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.init_tenant_defaults(p_tenant_id UUID, p_company_name TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name TEXT := COALESCE(NULLIF(trim(p_company_name), ''), 'WiFi Billing');
BEGIN
    -- app_settings (1 baris per tenant)
    INSERT INTO public.app_settings (
        tenant_id, app_name, app_short_name, app_tagline, app_description,
        offline_payment_name, show_qris, theme_color, background_color
    ) VALUES (
        p_tenant_id, v_name, left(v_name, 12), 'Internet Cepat & Tanpa Batas',
        'Sistem Manajemen Tagihan & Layanan Pelanggan Internet WiFi',
        'Kasir ' || v_name, TRUE, '#683fe4', '#f9f8fc'
    )
    ON CONFLICT (tenant_id) DO NOTHING;

    -- whatsapp_settings (key-value per tenant)
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

    -- genieacs_settings (nonaktif secara default)
    INSERT INTO public.genieacs_settings (tenant_id, setting_key, setting_value, is_enabled) VALUES
    (p_tenant_id, 'genieacs_enabled', 'false', FALSE),
    (p_tenant_id, 'genieacs_url', '', TRUE),
    (p_tenant_id, 'genieacs_username', '', TRUE),
    (p_tenant_id, 'genieacs_password', '', TRUE)
    ON CONFLICT (tenant_id, setting_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.init_tenant_defaults(UUID, TEXT) FROM PUBLIC, anon, authenticated;

-- Pastikan Default Tenant juga memiliki baris konfigurasi lengkap
SELECT public.init_tenant_defaults(public.default_tenant_id(), 'Rivamnet Default');

-- Helper pembuat slug unik
CREATE OR REPLACE FUNCTION public.generate_tenant_slug(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SET search_path = public
AS $$
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

-- ------------------------------------------------------------------------------
-- 7. Trigger handle_new_user (menggantikan 20250117_auto_create_profile.sql)
--
--   Skenario B (pelanggan dari Edge Function create-customer):
--     raw_app_meta_data.tenant_id terisi -> profil role 'USER' (pelanggan)
--     pada tenant tersebut.
--     CATATAN KEAMANAN: tenant_id hanya dipercaya dari raw_app_meta_data
--     (hanya bisa diset oleh service_role). raw_user_meta_data dapat diisi
--     bebas oleh siapa pun saat signUp, sehingga TIDAK dipercaya.
--
--   Skenario A (registrasi mitra baru dari register.js):
--     is_new_tenant = 'true' (atau tidak ada tenant_id sama sekali) ->
--       1. Buat tenant baru (company_name, paket Free Trial, 14 hari)
--       2. Buat profil role 'ADMIN'
--       3. Inisialisasi app_settings, whatsapp_settings, genieacs_settings
--       4. Simpan tenant_id & role ke raw_app_meta_data (via trigger sync)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_full_name   TEXT := COALESCE(NEW.raw_user_meta_data ->> 'full_name', '');
    v_tenant_id   UUID;
    v_role        TEXT;
    v_company     TEXT;
    v_plan_id     UUID;
    v_trial_days  INTEGER;
BEGIN
    -- Ambil tenant_id dari app_metadata (tepercaya)
    BEGIN
        v_tenant_id := NULLIF(NEW.raw_app_meta_data ->> 'tenant_id', '')::uuid;
    EXCEPTION WHEN others THEN
        v_tenant_id := NULL;
    END;

    IF v_tenant_id IS NOT NULL THEN
        -- ===================== SKENARIO B =====================
        IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_tenant_id) THEN
            RAISE EXCEPTION 'Tenant % tidak ditemukan.', v_tenant_id;
        END IF;

        -- Role dari app_metadata; hanya 'admin' atau 'pelanggan' yang diizinkan
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
        -- ===================== SKENARIO A =====================
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

    -- Klaim JWT disinkronkan oleh trigger profiles_sync_claims.
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

SELECT 'Fase 3 selesai: helper auth/role, default tenant_id, dan trigger handle_new_user multi-tenant aktif.' AS result;
