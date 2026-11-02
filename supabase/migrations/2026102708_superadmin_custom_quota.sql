-- ==============================================================================
-- FASE 8: Super Admin Features & Flexible Quota Override
-- ==============================================================================
-- Menambahkan custom_max_customers pada tabel tenants agar Super Admin
-- bisa mengatur batas jumlah pelanggan secara fleksibel per mitra (misal: 100, 300, 500, dll).
-- Juga menyediakan RPC get_superadmin_tenants() untuk kemudahan load dashboard Super Admin.
-- ==============================================================================

-- 1. Tambah kolom custom_max_customers pada tabel tenants
ALTER TABLE public.tenants
ADD COLUMN IF NOT EXISTS custom_max_customers INTEGER DEFAULT NULL;

COMMENT ON COLUMN public.tenants.custom_max_customers IS 
'Batas pelanggan kustom yang diatur Super Admin. Jika diisi, nilai ini meng-override max_customers dari saas_plans. NULL = ikuti saas_plans, -1 = unlimited.';

-- 2. Update RPC get_tenant_quota agar memperhitungkan custom_max_customers
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

-- 3. Update Trigger check_tenant_customer_quota agar memperhitungkan custom_max_customers
CREATE OR REPLACE FUNCTION public.check_tenant_customer_quota()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_max     INTEGER;
    v_status  TEXT;
    v_expires TIMESTAMPTZ;
    v_used    INTEGER;
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

-- 4. RPC Khusus Super Admin: get_superadmin_tenants()
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

-- 5. RPC Khusus Super Admin: update_tenant_by_superadmin()
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

SELECT 'Fase 8 selesai: custom_max_customers & Super Admin RPC aktif.' AS result;
