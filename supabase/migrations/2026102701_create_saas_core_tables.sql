-- ==============================================================================
-- FASE 1: Pembuatan Tabel Inti SaaS (Core Multi-Tenant Tables)
-- ==============================================================================
-- - saas_plans : Paket langganan SaaS untuk mitra RT/RW Net
-- - tenants    : Data mitra ISP / RT-RW Net
-- - Seed       : 3 paket default (Starter, Pro, Unlimited) + paket Free Trial
--                serta 1 Default Tenant penampung seluruh data eksisting.
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 0. Konstanta: ID Default Tenant (deterministik agar bisa direferensikan)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.default_tenant_id()
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT 'a0000000-0000-4000-8000-000000000001'::uuid;
$$;

COMMENT ON FUNCTION public.default_tenant_id() IS
    'ID tetap Default Tenant ("Rivamnet Default") yang menampung seluruh data single-tenant lama.';

-- Helper updated_at (sudah ada di Database.sql, dibuat ulang agar file mandiri)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 1. Tabel saas_plans
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.saas_plans (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           VARCHAR(100) NOT NULL,
    slug           VARCHAR(100) NOT NULL UNIQUE,
    price_monthly  NUMERIC(12,2) NOT NULL DEFAULT 0,
    max_customers  INTEGER,                 -- NULL = tanpa batas
    features       JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT saas_plans_max_customers_chk CHECK (max_customers IS NULL OR max_customers >= 0),
    CONSTRAINT saas_plans_price_chk CHECK (price_monthly >= 0)
);

COMMENT ON TABLE public.saas_plans IS 'Paket langganan SaaS untuk mitra RT/RW Net (tenant).';
COMMENT ON COLUMN public.saas_plans.max_customers IS 'Batas maksimal pelanggan WiFi aktif per tenant. NULL = unlimited.';

DROP TRIGGER IF EXISTS saas_plans_updated_at ON public.saas_plans;
CREATE TRIGGER saas_plans_updated_at
    BEFORE UPDATE ON public.saas_plans
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 2. Tabel tenants
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenants (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                     VARCHAR(150) NOT NULL,
    slug                     VARCHAR(100) NOT NULL UNIQUE,
    owner_id                 UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    plan_id                  UUID REFERENCES public.saas_plans(id) ON DELETE SET NULL,
    subscription_status      VARCHAR(20) NOT NULL DEFAULT 'trial',
    subscription_expires_at  TIMESTAMPTZ,
    logo_url                 TEXT,
    qris_url                 TEXT,
    company_address          TEXT,
    company_phone            VARCHAR(30),
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT tenants_subscription_status_chk
        CHECK (subscription_status IN ('trial', 'active', 'past_due', 'suspended')),
    CONSTRAINT tenants_slug_format_chk
        CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);

COMMENT ON TABLE public.tenants IS 'Mitra ISP / RT-RW Net (tenant) pada platform SaaS.';

CREATE INDEX IF NOT EXISTS idx_tenants_owner_id ON public.tenants(owner_id);
CREATE INDEX IF NOT EXISTS idx_tenants_plan_id ON public.tenants(plan_id);
CREATE INDEX IF NOT EXISTS idx_tenants_subscription_status ON public.tenants(subscription_status);

DROP TRIGGER IF EXISTS tenants_updated_at ON public.tenants;
CREATE TRIGGER tenants_updated_at
    BEFORE UPDATE ON public.tenants
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS diaktifkan sekarang (deny-by-default). Policy lengkap dipasang di Fase 4.
ALTER TABLE public.saas_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 3. Seed Data: Paket SaaS
-- ------------------------------------------------------------------------------
INSERT INTO public.saas_plans (name, slug, price_monthly, max_customers, features, is_active) VALUES
    ('Free Trial', 'free-trial', 0, 25,
        '{"whatsapp_gateway": true, "genieacs": false, "custom_receipt": false, "trial_days": 14}'::jsonb, TRUE),
    ('Starter', 'starter', 49000, 100,
        '{"whatsapp_gateway": true, "genieacs": false, "custom_receipt": true}'::jsonb, TRUE),
    ('Pro', 'pro', 149000, 500,
        '{"whatsapp_gateway": true, "genieacs": true, "custom_receipt": true}'::jsonb, TRUE),
    ('Unlimited', 'unlimited', 299000, NULL,
        '{"whatsapp_gateway": true, "genieacs": true, "custom_receipt": true, "priority_support": true}'::jsonb, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 4. Seed Data: Default Tenant (menampung seluruh data eksisting)
-- ------------------------------------------------------------------------------
INSERT INTO public.tenants (
    id, name, slug, owner_id, plan_id, subscription_status, subscription_expires_at,
    logo_url, qris_url, company_address, company_phone
)
SELECT
    public.default_tenant_id(),
    'Rivamnet Default',
    'rivamnet-default',
    -- Owner = admin pertama yang terdaftar (jika ada)
    (SELECT p.id FROM public.profiles p
       WHERE upper(p.role) IN ('ADMIN', 'TENANT_ADMIN')
       ORDER BY p.created_at ASC NULLS LAST
       LIMIT 1),
    (SELECT id FROM public.saas_plans WHERE slug = 'unlimited'),
    'active',
    NULL, -- tidak pernah kedaluwarsa
    (SELECT s.logo_url FROM public.app_settings s ORDER BY s.updated_at DESC NULLS LAST LIMIT 1),
    (SELECT s.qris_image_url FROM public.app_settings s ORDER BY s.updated_at DESC NULLS LAST LIMIT 1),
    (SELECT s.office_address FROM public.app_settings s ORDER BY s.updated_at DESC NULLS LAST LIMIT 1),
    (SELECT s.whatsapp_number FROM public.app_settings s ORDER BY s.updated_at DESC NULLS LAST LIMIT 1)
ON CONFLICT (id) DO NOTHING;

-- Grants (RLS tetap menjadi gerbang utama)
GRANT SELECT ON public.saas_plans TO anon, authenticated;
GRANT ALL ON public.saas_plans TO service_role;
GRANT SELECT, UPDATE ON public.tenants TO authenticated;
GRANT ALL ON public.tenants TO service_role;

SELECT 'Fase 1 selesai: saas_plans & tenants dibuat, Default Tenant di-seed.' AS result;
