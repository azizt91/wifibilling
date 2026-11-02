-- ==============================================================================
-- FASE 10: Otomatisasi Penghapusan Akun Auth Saat Tenant Dihapus
-- ==============================================================================
-- Masalah sebelumnya: saat tenant dihapus, baris profiles terhapus oleh cascade
-- foreign key, tetapi akun di Supabase Auth (auth.users) tetap tertinggal sebagai orphan.
--
-- Solusi:
-- 1. Trigger BEFORE DELETE pada public.tenants yang otomatis menghapus seluruh
--    akun auth.users (owner + semua pelanggan) sebelum data tenant terhapus.
-- 2. Memperbarui RPC delete_tenant_by_superadmin().
-- 3. Menambahkan RPC cleanup_orphan_auth_user(email) untuk membersihkan user auth
--    yang sebelumnya tertinggal.
-- ==============================================================================

-- 1. Trigger BEFORE DELETE pada public.tenants
CREATE OR REPLACE FUNCTION public.cascade_delete_tenant_auth_users()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    -- Hapus seluruh akun pelanggan di auth.users milik tenant ini
    DELETE FROM auth.users
    WHERE id IN (
        SELECT p.id FROM public.profiles p WHERE p.tenant_id = OLD.id
    );

    -- Hapus akun auth milik owner tenant
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

-- 2. Perbarui RPC delete_tenant_by_superadmin
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

    -- Hapus akun auth pelanggan
    DELETE FROM auth.users WHERE id IN (
        SELECT id FROM public.profiles WHERE tenant_id = p_tenant_id
    );

    -- Hapus akun auth owner
    IF v_owner_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_owner_id;
    END IF;

    -- Hapus tenant (cascade akan menghapus seluruh data operasional di profiles, invoices, packages, dll)
    DELETE FROM public.tenants WHERE id = p_tenant_id;

    RETURN jsonb_build_object('success', true, 'message', 'Mitra "' || v_name || '" berhasil dihapus beserta seluruh akun Auth dan datanya.');
END;
$$;

-- 3. Helper untuk membersihkan user orphan di auth.users berdasarkan email
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

