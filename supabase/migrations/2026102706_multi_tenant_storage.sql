-- ==============================================================================
-- FASE 6: Multi-Tenant Storage Buckets
-- ==============================================================================
-- Bucket 'tenant-assets' (public read) untuk logo & QRIS setiap tenant.
-- Pola path : {tenant_id}/logo.png , {tenant_id}/qris.png , {tenant_id}/...
-- Tulis (INSERT/UPDATE/DELETE) hanya oleh admin tenant pada folder tenant-nya.
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

-- 1. Bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'tenant-assets',
    'tenant-assets',
    TRUE,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml', 'image/x-icon']
)
ON CONFLICT (id) DO UPDATE SET
    public             = EXCLUDED.public,
    file_size_limit    = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Helper: apakah folder pertama path = tenant user (aman terhadap path non-UUID)
CREATE OR REPLACE FUNCTION public.storage_path_is_my_tenant(p_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
    v_folder TEXT := (storage.foldername(p_name))[1];
BEGIN
    IF v_folder IS NULL OR v_folder !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN FALSE;
    END IF;
    RETURN v_folder::uuid = public.get_my_tenant_id();
END;
$$;

GRANT EXECUTE ON FUNCTION public.storage_path_is_my_tenant(TEXT) TO authenticated;

-- 3. Policies pada storage.objects
DROP POLICY IF EXISTS "tenant_assets_public_read" ON storage.objects;
CREATE POLICY "tenant_assets_public_read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'tenant-assets');

DROP POLICY IF EXISTS "tenant_assets_admin_insert" ON storage.objects;
CREATE POLICY "tenant_assets_admin_insert"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'tenant-assets'
        AND (
            public.is_super_admin()
            OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))
        )
    );

DROP POLICY IF EXISTS "tenant_assets_admin_update" ON storage.objects;
CREATE POLICY "tenant_assets_admin_update"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'tenant-assets'
        AND (
            public.is_super_admin()
            OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))
        )
    )
    WITH CHECK (
        bucket_id = 'tenant-assets'
        AND (
            public.is_super_admin()
            OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))
        )
    );

DROP POLICY IF EXISTS "tenant_assets_admin_delete" ON storage.objects;
CREATE POLICY "tenant_assets_admin_delete"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'tenant-assets'
        AND (
            public.is_super_admin()
            OR (public.is_tenant_admin() AND public.storage_path_is_my_tenant(name))
        )
    );

SELECT 'Fase 6 selesai: bucket tenant-assets & storage RLS per-tenant aktif.' AS result;
