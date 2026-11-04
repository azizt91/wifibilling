-- ====================================================================
-- Migrasi: Pelacakan Analitik Aplikasi Mobile (Download & Instalasi)
-- File: supabase/migrations/2026110401_create_mobile_app_analytics.sql
-- ====================================================================

-- 1. Tabel Riwayat Download APK
CREATE TABLE IF NOT EXISTS public.app_downloads (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
    downloaded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_agent     TEXT,
    referrer       TEXT
);

CREATE INDEX IF NOT EXISTS idx_app_downloads_tenant ON public.app_downloads(tenant_id);
CREATE INDEX IF NOT EXISTS idx_app_downloads_date ON public.app_downloads(downloaded_at DESC);

-- 2. Tabel Riwayat Perangkat Terpasang (Installs / First Open)
CREATE TABLE IF NOT EXISTS public.app_installations (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id          TEXT NOT NULL UNIQUE,
    device_model       VARCHAR(100),
    os_version         VARCHAR(50),
    app_version        VARCHAR(50),
    tenant_id          UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
    first_installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_installs_device ON public.app_installations(device_id);
CREATE INDEX IF NOT EXISTS idx_app_installs_tenant ON public.app_installations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_app_installs_date ON public.app_installations(first_installed_at DESC);

-- 3. Enable RLS
ALTER TABLE public.app_downloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_installations ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies: Hanya Super Admin yang bisa melihat data mentah secara langsung
DROP POLICY IF EXISTS app_downloads_super_admin_all ON public.app_downloads;
CREATE POLICY app_downloads_super_admin_all ON public.app_downloads
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

DROP POLICY IF EXISTS app_installations_super_admin_all ON public.app_installations;
CREATE POLICY app_installations_super_admin_all ON public.app_installations
    FOR ALL TO authenticated
    USING ((SELECT public.is_super_admin()))
    WITH CHECK ((SELECT public.is_super_admin()));

-- 5. RPC Function: record_apk_download
-- Dipanggil saat tombol download diklik di web (dapat diakses publik/anon)
CREATE OR REPLACE FUNCTION public.record_apk_download(
    p_tenant_slug TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_referrer TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant_id UUID := NULL;
    v_total_downloads BIGINT;
BEGIN
    IF p_tenant_slug IS NOT NULL AND p_tenant_slug <> '' THEN
        SELECT id INTO v_tenant_id FROM public.tenants WHERE slug = lower(trim(p_tenant_slug)) LIMIT 1;
    END IF;

    INSERT INTO public.app_downloads (tenant_id, downloaded_at, user_agent, referrer)
    VALUES (v_tenant_id, NOW(), p_user_agent, p_referrer);

    SELECT COUNT(*) INTO v_total_downloads FROM public.app_downloads;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total_downloads', v_total_downloads
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_apk_download(TEXT, TEXT, TEXT) TO anon, authenticated;

-- 6. RPC Function: record_app_installation
-- Dipanggil saat aplikasi APK dibuka pertama kali di HP (dapat diakses publik/anon)
CREATE OR REPLACE FUNCTION public.record_app_installation(
    p_device_id TEXT,
    p_device_model TEXT DEFAULT NULL,
    p_os_version TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL,
    p_tenant_slug TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant_id UUID := NULL;
    v_is_new BOOLEAN := FALSE;
    v_total_installs BIGINT;
BEGIN
    IF p_device_id IS NULL OR trim(p_device_id) = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'device_id is required');
    END IF;

    IF p_tenant_slug IS NOT NULL AND p_tenant_slug <> '' THEN
        SELECT id INTO v_tenant_id FROM public.tenants WHERE slug = lower(trim(p_tenant_slug)) LIMIT 1;
    END IF;

    IF EXISTS (SELECT 1 FROM public.app_installations WHERE device_id = p_device_id) THEN
        UPDATE public.app_installations
        SET last_active_at = NOW(),
            device_model = COALESCE(p_device_model, device_model),
            os_version = COALESCE(p_os_version, os_version),
            app_version = COALESCE(p_app_version, app_version),
            tenant_id = COALESCE(v_tenant_id, tenant_id)
        WHERE device_id = p_device_id;
        v_is_new := FALSE;
    ELSE
        INSERT INTO public.app_installations (device_id, device_model, os_version, app_version, tenant_id, first_installed_at, last_active_at)
        VALUES (p_device_id, p_device_model, p_os_version, p_app_version, v_tenant_id, NOW(), NOW());
        v_is_new := TRUE;
    END IF;

    SELECT COUNT(*) INTO v_total_installs FROM public.app_installations;

    RETURN jsonb_build_object(
        'success', TRUE,
        'is_new', v_is_new,
        'total_installs', v_total_installs
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_app_installation(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- 7. RPC Function: get_superadmin_app_stats
-- Khusus Super Admin: mengambil total download, total install, conversion rate, dan daftar perangkat terbaru
CREATE OR REPLACE FUNCTION public.get_superadmin_app_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_downloads BIGINT := 0;
    v_total_installs BIGINT := 0;
    v_conversion_rate NUMERIC := 0;
    v_recent_installs JSONB := '[]'::jsonb;
    v_recent_downloads JSONB := '[]'::jsonb;
BEGIN
    -- Hitung total
    SELECT COUNT(*) INTO v_total_downloads FROM public.app_downloads;
    SELECT COUNT(*) INTO v_total_installs FROM public.app_installations;

    -- Hitung rasio konversi (installs / downloads * 100%)
    IF v_total_downloads > 0 THEN
        v_conversion_rate := ROUND((v_total_installs::numeric / v_total_downloads::numeric) * 100, 1);
    ELSE
        IF v_total_installs > 0 THEN
            v_conversion_rate := 100.0;
        ELSE
            v_conversion_rate := 0.0;
        END IF;
    END IF;

    -- 10 Perangkat Terpasang Terbaru
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', i.id,
            'device_id', i.device_id,
            'device_model', COALESCE(i.device_model, 'Android Device'),
            'os_version', COALESCE(i.os_version, 'Android'),
            'app_version', COALESCE(i.app_version, 'v1.0.0'),
            'tenant_name', t.name,
            'first_installed_at', i.first_installed_at,
            'last_active_at', i.last_active_at
        ) ORDER BY i.first_installed_at DESC
    ), '[]'::jsonb)
    INTO v_recent_installs
    FROM (
        SELECT * FROM public.app_installations ORDER BY first_installed_at DESC LIMIT 10
    ) i
    LEFT JOIN public.tenants t ON t.id = i.tenant_id;

    -- 10 Unduhan Terbaru
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', d.id,
            'downloaded_at', d.downloaded_at,
            'tenant_name', t.name,
            'user_agent', d.user_agent,
            'referrer', d.referrer
        ) ORDER BY d.downloaded_at DESC
    ), '[]'::jsonb)
    INTO v_recent_downloads
    FROM (
        SELECT * FROM public.app_downloads ORDER BY downloaded_at DESC LIMIT 10
    ) d
    LEFT JOIN public.tenants t ON t.id = d.tenant_id;

    RETURN jsonb_build_object(
        'total_downloads', v_total_downloads,
        'total_installs', v_total_installs,
        'conversion_rate', v_conversion_rate,
        'recent_installs', v_recent_installs,
        'recent_downloads', v_recent_downloads
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_superadmin_app_stats() TO anon, authenticated;
