-- ==============================================================================
-- FASE 4: Isolasi Row Level Security (RLS) Multi-Tenant
-- ==============================================================================
-- Seluruh policy lama (global / USING (true)) pada tabel aplikasi dihapus,
-- lalu diganti policy berbasis tenant_id.
--
-- Pola performa: helper dibungkus "(SELECT ...)" agar dievaluasi sekali per
-- statement (initPlan), bukan per baris.
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. Hapus SEMUA policy lama pada tabel aplikasi
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
              'saas_plans', 'tenants', 'profiles', 'packages', 'invoices', 'expenses',
              'payment_methods', 'notifications', 'notification_reads', 'app_settings',
              'whatsapp_settings', 'genieacs_settings', 'wifi_change_logs'
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
    END LOOP;
END $$;

-- Pastikan RLS aktif di semua tabel
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

-- Cabut hak anon yang dulu diberikan terlalu luas (lihat 20261024_fix_whatsapp_settings.sql)
REVOKE ALL ON public.whatsapp_settings FROM anon;
REVOKE ALL ON public.genieacs_settings FROM anon;
REVOKE ALL ON public.tenants FROM anon;

-- ==============================================================================
-- 1. saas_plans
-- ==============================================================================
CREATE POLICY saas_plans_public_read ON public.saas_plans
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE OR (SELECT public.is_super_admin()));

CREATE POLICY saas_plans_super_admin_all ON public.saas_plans
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

-- ==============================================================================
-- 2. tenants
-- ==============================================================================
CREATE POLICY tenants_super_admin_all ON public.tenants
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY tenants_admin_select ON public.tenants
    FOR SELECT TO authenticated
    USING (
        (SELECT public.is_tenant_admin())
        AND id = (SELECT public.get_my_tenant_id())
    );

CREATE POLICY tenants_admin_update ON public.tenants
    FOR UPDATE TO authenticated
    USING (
        (SELECT public.is_tenant_admin())
        AND id = (SELECT public.get_my_tenant_id())
    )
    WITH CHECK (
        (SELECT public.is_tenant_admin())
        AND id = (SELECT public.get_my_tenant_id())
    );

-- Admin tenant tidak boleh mengubah kolom billing/kepemilikan SaaS
CREATE OR REPLACE FUNCTION public.protect_tenant_billing_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.is_service_context() OR public.is_super_admin() THEN
        RETURN NEW;
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.slug IS DISTINCT FROM OLD.slug
       OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
       OR NEW.plan_id IS DISTINCT FROM OLD.plan_id
       OR NEW.subscription_status IS DISTINCT FROM OLD.subscription_status
       OR NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
        RAISE EXCEPTION 'Anda tidak diizinkan mengubah data langganan / kepemilikan tenant.'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tenants_protect_billing ON public.tenants;
CREATE TRIGGER tenants_protect_billing
    BEFORE UPDATE ON public.tenants
    FOR EACH ROW EXECUTE FUNCTION public.protect_tenant_billing_columns();

-- Pelanggan: SELECT terbatas (nama usaha, logo, QRIS, kontak) via view.
-- View berjalan dengan hak owner (bukan security_invoker) sehingga hanya
-- kolom publik ini yang dapat dibaca pelanggan, terbatas pada tenant-nya.
CREATE OR REPLACE VIEW public.tenant_public_profile AS
SELECT t.id, t.name, t.slug, t.logo_url, t.qris_url, t.company_address, t.company_phone
FROM public.tenants t
WHERE t.id = public.get_my_tenant_id()
   OR public.is_super_admin();

REVOKE ALL ON public.tenant_public_profile FROM anon;
GRANT SELECT ON public.tenant_public_profile TO authenticated;

-- ==============================================================================
-- 3. profiles
-- ==============================================================================
CREATE POLICY profiles_super_admin_all ON public.profiles
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY profiles_admin_tenant_all ON public.profiles
    FOR ALL TO authenticated
    USING (
        (SELECT public.is_tenant_admin())
        AND tenant_id = (SELECT public.get_my_tenant_id())
    )
    WITH CHECK (
        (SELECT public.is_tenant_admin())
        AND tenant_id = (SELECT public.get_my_tenant_id())
    );

CREATE POLICY profiles_self_select ON public.profiles
    FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()));

CREATE POLICY profiles_self_update ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = (SELECT auth.uid()))
    WITH CHECK (id = (SELECT auth.uid()));

-- Cegah eskalasi hak akses: user biasa tidak boleh mengubah role / tenant_id
CREATE OR REPLACE FUNCTION public.protect_profile_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_my_role   TEXT;
    v_my_tenant UUID;
BEGIN
    IF public.is_service_context() OR public.is_super_admin() THEN
        RETURN NEW;
    END IF;

    v_my_role   := public.get_my_role();
    v_my_tenant := public.get_my_tenant_id();

    IF public.normalize_role(NEW.role) = 'super_admin' THEN
        RAISE EXCEPTION 'Role SUPER_ADMIN hanya dapat diberikan oleh pemilik platform.'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'INSERT' THEN
        NEW.tenant_id := COALESCE(NEW.tenant_id, v_my_tenant);
        IF NEW.tenant_id IS DISTINCT FROM v_my_tenant THEN
            RAISE EXCEPTION 'Tidak dapat membuat profil di tenant lain.' USING ERRCODE = '42501';
        END IF;
        IF v_my_role IS DISTINCT FROM 'admin' AND public.normalize_role(NEW.role) <> 'pelanggan' THEN
            RAISE EXCEPTION 'Anda tidak diizinkan menetapkan role tersebut.' USING ERRCODE = '42501';
        END IF;
        RETURN NEW;
    END IF;

    -- UPDATE
    IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
        RAISE EXCEPTION 'tenant_id tidak dapat diubah.' USING ERRCODE = '42501';
    END IF;

    IF public.normalize_role(NEW.role) IS DISTINCT FROM public.normalize_role(OLD.role) THEN
        IF v_my_role IS DISTINCT FROM 'admin' THEN
            RAISE EXCEPTION 'Anda tidak diizinkan mengubah role.' USING ERRCODE = '42501';
        END IF;
        IF NEW.id = auth.uid() THEN
            RAISE EXCEPTION 'Anda tidak dapat mengubah role akun Anda sendiri.' USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_protect_privileged ON public.profiles;
CREATE TRIGGER profiles_protect_privileged
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privileged_columns();

-- ==============================================================================
-- 4. Tabel operasional: packages & payment_methods
--    super_admin: ALL | admin: ALL (tenant) | pelanggan: SELECT (tenant)
-- ==============================================================================
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['packages', 'payment_methods'] LOOP
        EXECUTE format($f$
            CREATE POLICY %1$I ON public.%2$I
                FOR ALL TO authenticated
                USING ((SELECT public.is_super_admin()))
                WITH CHECK ((SELECT public.is_super_admin()))
        $f$, t || '_super_admin_all', t);

        EXECUTE format($f$
            CREATE POLICY %1$I ON public.%2$I
                FOR ALL TO authenticated
                USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
                WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
        $f$, t || '_admin_tenant_all', t);

        EXECUTE format($f$
            CREATE POLICY %1$I ON public.%2$I
                FOR SELECT TO authenticated
                USING (tenant_id = (SELECT public.get_my_tenant_id()))
        $f$, t || '_member_select', t);
    END LOOP;
END $$;

-- ==============================================================================
-- 5. invoices
--    pelanggan: SELECT hanya tagihan miliknya sendiri di tenant-nya
-- ==============================================================================
CREATE POLICY invoices_super_admin_all ON public.invoices
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY invoices_admin_tenant_all ON public.invoices
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

CREATE POLICY invoices_customer_select_own ON public.invoices
    FOR SELECT TO authenticated
    USING (
        tenant_id = (SELECT public.get_my_tenant_id())
        AND customer_id = (SELECT auth.uid())
    );

-- ==============================================================================
-- 6. expenses (pelanggan: tidak ada akses)
-- ==============================================================================
CREATE POLICY expenses_super_admin_all ON public.expenses
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY expenses_admin_tenant_all ON public.expenses
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

-- ==============================================================================
-- 7. notifications
--    pelanggan: SELECT notifikasi miliknya (recipient_user_id) atau broadcast
--    ke role-nya, di dalam tenant-nya.
-- ==============================================================================
CREATE POLICY notifications_super_admin_all ON public.notifications
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY notifications_admin_tenant_all ON public.notifications
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

CREATE POLICY notifications_customer_select_own ON public.notifications
    FOR SELECT TO authenticated
    USING (
        tenant_id = (SELECT public.get_my_tenant_id())
        AND (
            recipient_user_id = (SELECT auth.uid())
            OR (
                recipient_user_id IS NULL
                AND public.normalize_role(recipient_role) = (SELECT public.get_my_role())
            )
        )
    );

-- Pelanggan boleh membuat notifikasi (mis. konfirmasi pembayaran) hanya di tenant-nya
CREATE POLICY notifications_member_insert ON public.notifications
    FOR INSERT TO authenticated
    WITH CHECK (tenant_id = (SELECT public.get_my_tenant_id()));

-- notification_reads: tetap per-user
CREATE POLICY notification_reads_own_all ON public.notification_reads
    FOR ALL TO authenticated
    USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

-- ==============================================================================
-- 8. Tabel kredensial / pengaturan
-- ==============================================================================

-- 8.1 app_settings: admin ALL (tenant), pelanggan SELECT (tenant)
CREATE POLICY app_settings_super_admin_all ON public.app_settings
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY app_settings_admin_tenant_all ON public.app_settings
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

CREATE POLICY app_settings_member_select ON public.app_settings
    FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()));

-- Branding halaman login (pengunjung anonim) memakai pengaturan Default Tenant.
-- Kolom app_settings tidak berisi kredensial.
CREATE POLICY app_settings_anon_default_branding ON public.app_settings
    FOR SELECT TO anon
    USING (tenant_id = public.default_tenant_id());

-- 8.2 whatsapp_settings: HANYA admin tenant (menyimpan API token Fonnte)
CREATE POLICY whatsapp_settings_super_admin_all ON public.whatsapp_settings
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY whatsapp_settings_admin_tenant_all ON public.whatsapp_settings
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

-- 8.3 genieacs_settings: HANYA admin tenant (menyimpan password server ACS)
CREATE POLICY genieacs_settings_super_admin_all ON public.genieacs_settings
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY genieacs_settings_admin_tenant_all ON public.genieacs_settings
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

-- Pelanggan hanya perlu tahu apakah fitur ganti WiFi aktif (tanpa kredensial)
CREATE OR REPLACE FUNCTION public.get_genieacs_status()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((
        SELECT lower(setting_value) = 'true'
        FROM public.genieacs_settings
        WHERE tenant_id = public.get_my_tenant_id()
          AND setting_key = 'genieacs_enabled'
        LIMIT 1
    ), FALSE);
$$;

REVOKE ALL ON FUNCTION public.get_genieacs_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_genieacs_status() TO authenticated;

-- ==============================================================================
-- 9. wifi_change_logs
-- ==============================================================================
CREATE POLICY wifi_logs_super_admin_all ON public.wifi_change_logs
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

CREATE POLICY wifi_logs_admin_tenant_all ON public.wifi_change_logs
    FOR ALL TO authenticated
    USING ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()))
    WITH CHECK ((SELECT public.is_tenant_admin()) AND tenant_id = (SELECT public.get_my_tenant_id()));

CREATE POLICY wifi_logs_customer_select_own ON public.wifi_change_logs
    FOR SELECT TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));

CREATE POLICY wifi_logs_customer_insert_own ON public.wifi_change_logs
    FOR INSERT TO authenticated
    WITH CHECK (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));

CREATE POLICY wifi_logs_customer_update_own ON public.wifi_change_logs
    FOR UPDATE TO authenticated
    USING (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()))
    WITH CHECK (tenant_id = (SELECT public.get_my_tenant_id()) AND customer_id = (SELECT auth.uid()));

-- Backup legacy hanya untuk service_role (tanpa policy = deny untuk anon/authenticated)
REVOKE ALL ON public.app_settings_legacy_backup FROM anon, authenticated;

SELECT 'Fase 4 selesai: RLS multi-tenant terpasang di seluruh tabel.' AS result;
