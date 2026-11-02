-- ==============================================================================
-- FASE 5: Penegakan Kuota Langganan SaaS (Database-Level Quota Enforcement)
-- ==============================================================================
-- Trigger BEFORE INSERT / UPDATE pada public.profiles:
--   - Berlaku saat baris menjadi pelanggan (role 'USER' / 'pelanggan') berstatus AKTIF
--   - Tolak bila langganan tenant tidak aktif (suspended / past_due / expired)
--   - Tolak bila jumlah pelanggan aktif >= saas_plans.max_customers
-- Konteks service_role (Edge Function) TETAP dicek. Hanya super admin yang
-- boleh melewati kuota (agar pemilik platform bisa memperbaiki data).
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Fungsi informasi kuota (dipakai trigger, Edge Function, dan UI)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_tenant_quota(p_tenant_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant_id UUID := COALESCE(p_tenant_id, public.get_my_tenant_id());
    v_max       INTEGER;
    v_plan_name TEXT;
    v_used      INTEGER;
    v_active    BOOLEAN;
    v_status    TEXT;
    v_expires   TIMESTAMPTZ;
BEGIN
    -- Non-super-admin hanya boleh melihat kuota tenant-nya sendiri
    IF NOT public.is_service_context()
       AND NOT public.is_super_admin()
       AND v_tenant_id IS DISTINCT FROM public.get_my_tenant_id() THEN
        RAISE EXCEPTION 'Akses ditolak.' USING ERRCODE = '42501';
    END IF;

    SELECT sp.max_customers, sp.name, t.subscription_status, t.subscription_expires_at
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
        'max_customers', v_max,          -- NULL = unlimited
        'used_customers', v_used,
        'remaining', CASE WHEN v_max IS NULL THEN NULL ELSE GREATEST(v_max - v_used, 0) END,
        'can_add_customer', v_active AND (v_max IS NULL OR v_used < v_max)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_tenant_quota(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_tenant_quota(UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. Trigger function check_tenant_customer_quota()
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_tenant_customer_quota()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_max     INTEGER;
    v_used    INTEGER;
    v_status  TEXT;
    v_expires TIMESTAMPTZ;
BEGIN
    -- Hanya relevan untuk pelanggan aktif
    IF public.normalize_role(NEW.role) <> 'pelanggan'
       OR NEW.status IS DISTINCT FROM 'AKTIF'
       OR NEW.tenant_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- UPDATE yang tidak menambah jumlah pelanggan aktif tidak perlu dicek
    IF TG_OP = 'UPDATE'
       AND public.normalize_role(OLD.role) = 'pelanggan'
       AND OLD.status = 'AKTIF'
       AND OLD.tenant_id = NEW.tenant_id THEN
        RETURN NEW;
    END IF;

    -- Super admin boleh melewati kuota (perbaikan data manual)
    IF public.is_super_admin() THEN
        RETURN NEW;
    END IF;

    -- Kunci baris tenant agar penghitungan kuota aman dari race condition
    SELECT sp.max_customers, t.subscription_status, t.subscription_expires_at
      INTO v_max, v_status, v_expires
    FROM public.tenants t
    LEFT JOIN public.saas_plans sp ON sp.id = t.plan_id
    WHERE t.id = NEW.tenant_id
    FOR UPDATE OF t;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tenant tidak ditemukan.' USING ERRCODE = 'P0001';
    END IF;

    IF NOT public.is_tenant_active(NEW.tenant_id) THEN
        RAISE EXCEPTION 'Masa aktif langganan SaaS Anda telah berakhir atau ditangguhkan (status: %). Silakan perpanjang langganan untuk menambah pelanggan.',
            CASE
                WHEN v_status IN ('active', 'trial') AND v_expires IS NOT NULL AND v_expires <= NOW()
                    THEN 'expired'
                ELSE v_status
            END
            USING ERRCODE = 'P0001', HINT = 'TENANT_INACTIVE';
    END IF;

    IF v_max IS NOT NULL THEN
        SELECT COUNT(*)::INTEGER INTO v_used
        FROM public.profiles p
        WHERE p.tenant_id = NEW.tenant_id
          AND public.normalize_role(p.role) = 'pelanggan'
          AND p.status = 'AKTIF'
          AND p.id <> NEW.id;

        IF v_used >= v_max THEN
            RAISE EXCEPTION 'Kuota pelanggan untuk paket langganan Anda telah penuh. Silakan upgrade paket SaaS Anda.'
                USING ERRCODE = 'P0001', HINT = 'QUOTA_EXCEEDED',
                      DETAIL = format('Terpakai %s dari %s pelanggan aktif.', v_used, v_max);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_check_tenant_quota ON public.profiles;
CREATE TRIGGER profiles_check_tenant_quota
    BEFORE INSERT OR UPDATE OF role, status, tenant_id ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.check_tenant_customer_quota();

SELECT 'Fase 5 selesai: penegakan kuota & masa aktif langganan aktif di level database.' AS result;
