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

