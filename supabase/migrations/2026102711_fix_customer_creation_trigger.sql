-- ==============================================================================
-- FASE 11: Fix Trigger handle_new_user (Mencegah Pelanggan Menjadi Tenant)
-- ==============================================================================
-- Masalah sebelumnya: saat admin mitra membuat pelanggan baru via create-customer,
-- NEW.raw_app_meta_data belum terbaca di hook insert auth.users.
-- Akibatnya trigger masuk ke Skenario A dan membuatkan tenant baru untuk si pelanggan!
--
-- Solusi:
-- 1. Baca tenant_id, role, dan user_type dari raw_app_meta_data MAUPUN raw_user_meta_data.
-- 2. Jika v_tenant_id terisi, ATAU role/user_type adalah pelanggan/customer,
--    MAKA PASTI masuk Skenario B (hanya buat/update profil, TIDAK PERNAH membuat tenant baru).
-- 3. Bersihkan tenant anomali "Batrex" tanpa menghapus akun login dan profil pelanggan.
-- ==============================================================================

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
    v_user_type   TEXT;
    v_company     TEXT;
    v_plan_id     UUID;
    v_trial_days  INTEGER;
    v_is_customer BOOLEAN := FALSE;
BEGIN
    -- 1. Ambil tenant_id (bisa dari app_metadata atau user_metadata)
    BEGIN
        v_tenant_id := NULLIF(COALESCE(
            NEW.raw_app_meta_data ->> 'tenant_id',
            NEW.raw_user_meta_data ->> 'tenant_id'
        ), '')::uuid;
    EXCEPTION WHEN others THEN
        v_tenant_id := NULL;
    END;

    -- 2. Deteksi apakah ini akun pelanggan
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

    -- ===================== SKENARIO B: PELANGGAN / USER DENGAN TENANT =====================
    IF v_tenant_id IS NOT NULL OR v_is_customer THEN
        -- Fallback default tenant bila tenant_id tidak valid
        IF v_tenant_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_tenant_id) THEN
            v_tenant_id := public.default_tenant_id();
        END IF;

        v_role := CASE
            WHEN v_role = 'admin' THEN 'ADMIN'
            ELSE 'USER'
        END;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id)
        VALUES (NEW.id, v_full_name, v_role, 'AKTIF', 'assets/avatar_male.svg', v_tenant_id)
        ON CONFLICT (id) DO UPDATE SET
            full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
            role      = EXCLUDED.role,
            tenant_id = EXCLUDED.tenant_id;

    -- ===================== SKENARIO A: MITRA BARU (HANYA JIKA BUKAN PELANGGAN) =====================
    ELSE
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

-- 3. Pembersihan tenant anomali "Batrex":
-- Lepaskan owner_id agar trigger cascade tidak menghapus user login Batrex
UPDATE public.tenants 
SET owner_id = NULL 
WHERE slug = 'batrex-497c5f' OR (name = 'Batrex' AND plan_id = (SELECT id FROM public.saas_plans WHERE slug = 'free-trial' LIMIT 1));

-- Hapus baris tenant anomali Batrex
DELETE FROM public.tenants 
WHERE slug = 'batrex-497c5f' OR (name = 'Batrex' AND owner_id IS NULL);

