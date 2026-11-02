-- FASE 9: RPC Hapus Mitra untuk Super Admin
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
