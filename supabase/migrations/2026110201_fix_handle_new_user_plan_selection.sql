-- Migration: Update handle_new_user to respect selected plan, handle customer creation, and save phone
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_full_name   TEXT := COALESCE(NEW.raw_user_meta_data ->> 'full_name', '');
    v_phone       TEXT := NULLIF(trim(COALESCE(NEW.raw_user_meta_data ->> 'phone', NEW.raw_user_meta_data ->> 'whatsapp_number')), '');
    v_tenant_id   UUID;
    v_role        TEXT;
    v_user_type   TEXT;
    v_company     TEXT;
    v_plan_id     UUID;
    v_plan_raw    TEXT;
    v_plan_slug   TEXT;
    v_trial_days  INTEGER;
    v_is_customer BOOLEAN := FALSE;
BEGIN
    -- Ambil tenant_id dari app_metadata atau user_metadata
    BEGIN
        v_tenant_id := NULLIF(COALESCE(
            NEW.raw_app_meta_data ->> 'tenant_id',
            NEW.raw_user_meta_data ->> 'tenant_id'
        ), '')::uuid;
    EXCEPTION WHEN others THEN
        v_tenant_id := NULL;
    END;

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

    IF v_tenant_id IS NOT NULL OR v_is_customer THEN
        -- ===================== SKENARIO B: Pelanggan / Anggota Tenant =====================
        IF v_tenant_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = v_tenant_id) THEN
            v_tenant_id := public.default_tenant_id();
        END IF;

        v_role := CASE
            WHEN v_role = 'admin' THEN 'ADMIN'
            ELSE 'USER'
        END;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id, whatsapp_number)
        VALUES (NEW.id, v_full_name, v_role, 'AKTIF', 'assets/avatar_male.svg', v_tenant_id, v_phone)
        ON CONFLICT (id) DO UPDATE SET
            full_name       = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.profiles.full_name),
            role            = EXCLUDED.role,
            tenant_id       = EXCLUDED.tenant_id,
            whatsapp_number = COALESCE(EXCLUDED.whatsapp_number, public.profiles.whatsapp_number);
    ELSE
        -- ===================== SKENARIO A: Calon Mitra Baru (Pendaftaran SaaS) =====================
        v_company := COALESCE(
            NULLIF(trim(NEW.raw_user_meta_data ->> 'company_name'), ''),
            NULLIF(trim(v_full_name), ''),
            split_part(COALESCE(NEW.email, 'tenant'), '@', 1)
        );

        -- Ambil paket dari metadata (plan_slug atau plan_name)
        v_plan_raw := lower(trim(COALESCE(
            NEW.raw_user_meta_data ->> 'plan_slug',
            NEW.raw_user_meta_data ->> 'plan_name',
            'free-trial'
        )));

        -- Normalisasi slug paket
        IF v_plan_raw LIKE '%starter%' THEN
            v_plan_slug := 'starter';
        ELSIF v_plan_raw LIKE '%pro%' THEN
            v_plan_slug := 'pro';
        ELSIF v_plan_raw LIKE '%unlimited%' THEN
            v_plan_slug := 'unlimited';
        ELSE
            v_plan_slug := 'free-trial';
        END IF;

        -- Cari plan_id di saas_plans
        SELECT id, COALESCE((features ->> 'trial_days')::int, 14)
          INTO v_plan_id, v_trial_days
        FROM public.saas_plans
        WHERE slug = v_plan_slug OR lower(name) = v_plan_slug
        LIMIT 1;

        -- Fallback ke free-trial jika tidak ditemukan
        IF v_plan_id IS NULL THEN
            SELECT id, COALESCE((features ->> 'trial_days')::int, 14)
              INTO v_plan_id, v_trial_days
            FROM public.saas_plans
            WHERE slug = 'free-trial'
            LIMIT 1;
        END IF;

        INSERT INTO public.tenants (
            name, slug, owner_id, plan_id, subscription_status, subscription_expires_at, company_phone
        ) VALUES (
            v_company,
            public.generate_tenant_slug(v_company),
            NEW.id,
            v_plan_id,
            'trial',
            NOW() + make_interval(days => COALESCE(v_trial_days, 14)),
            v_phone
        )
        RETURNING id INTO v_tenant_id;

        INSERT INTO public.profiles (id, full_name, role, status, photo_url, tenant_id, whatsapp_number)
        VALUES (NEW.id, v_full_name, 'ADMIN', 'AKTIF', 'assets/avatar_male.svg', v_tenant_id, v_phone)
        ON CONFLICT (id) DO UPDATE SET
            full_name       = EXCLUDED.full_name,
            role            = 'ADMIN',
            tenant_id       = EXCLUDED.tenant_id,
            whatsapp_number = COALESCE(EXCLUDED.whatsapp_number, public.profiles.whatsapp_number);

        PERFORM public.init_tenant_defaults(v_tenant_id, v_company);
    END IF;

    RETURN NEW;
END;
$$;
