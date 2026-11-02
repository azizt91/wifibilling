-- ==============================================================================
-- FASE 2: Injeksi tenant_id ke Seluruh Tabel Eksisting
-- ==============================================================================
-- Untuk setiap tabel operasional:
--   1. ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE
--   2. Backfill baris lama -> Default Tenant (Zero Data Loss)
--   3. SET NOT NULL (profiles: CHECK agar SUPER_ADMIN boleh NULL)
--   4. CREATE INDEX idx_<tabel>_tenant_id
-- Kemudian unique constraint global diubah menjadi per-tenant.
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Tambah kolom, backfill, NOT NULL, index (tabel operasional)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    t TEXT;
    tables TEXT[] := ARRAY[
        'packages',
        'invoices',
        'expenses',
        'payment_methods',
        'notifications',
        'app_settings',
        'whatsapp_settings',
        'genieacs_settings',
        'wifi_change_logs'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF to_regclass('public.' || t) IS NULL THEN
            RAISE NOTICE 'Tabel public.% tidak ditemukan, dilewati.', t;
            CONTINUE;
        END IF;

        EXECUTE format(
            'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE',
            t);

        EXECUTE format(
            'UPDATE public.%I SET tenant_id = public.default_tenant_id() WHERE tenant_id IS NULL',
            t);

        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN tenant_id SET NOT NULL', t);

        EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(tenant_id)',
            'idx_' || t || '_tenant_id', t);
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Tabel profiles (pengecualian: SUPER_ADMIN boleh tanpa tenant)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

UPDATE public.profiles
SET tenant_id = public.default_tenant_id()
WHERE tenant_id IS NULL
  AND upper(COALESCE(role, '')) <> 'SUPER_ADMIN';

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_tenant_required_chk;
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_tenant_required_chk
    CHECK (tenant_id IS NOT NULL OR upper(role) = 'SUPER_ADMIN');

CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_role_status ON public.profiles(tenant_id, role, status);

-- Index komposit tambahan untuk kueri yang paling sering dipakai
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_customer ON public.invoices(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_period ON public.invoices(tenant_id, invoice_period);
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_date ON public.expenses(tenant_id, expense_date);

-- ------------------------------------------------------------------------------
-- 3. Helper: hapus UNIQUE constraint / unique index yang hanya pada kolom tertentu
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._drop_single_column_unique(p_table TEXT, p_column TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    -- Unique constraints
    FOR r IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class tbl ON tbl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = tbl.relnamespace
        WHERE n.nspname = 'public'
          AND tbl.relname = p_table
          AND c.contype = 'u'
          AND array_length(c.conkey, 1) = 1
          AND c.conkey[1] = (
              SELECT a.attnum FROM pg_attribute a
              WHERE a.attrelid = tbl.oid AND a.attname = p_column
          )
    LOOP
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', p_table, r.conname);
        RAISE NOTICE 'Dropped unique constraint %.%', p_table, r.conname;
    END LOOP;

    -- Unique indexes mandiri (bukan milik constraint)
    FOR r IN
        SELECT i.relname AS idxname
        FROM pg_index x
        JOIN pg_class i ON i.oid = x.indexrelid
        JOIN pg_class tbl ON tbl.oid = x.indrelid
        JOIN pg_namespace n ON n.oid = tbl.relnamespace
        WHERE n.nspname = 'public'
          AND tbl.relname = p_table
          AND x.indisunique
          AND NOT x.indisprimary
          AND x.indnatts = 1
          AND x.indkey[0] = (
              SELECT a.attnum FROM pg_attribute a
              WHERE a.attrelid = tbl.oid AND a.attname = p_column
          )
          AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conindid = x.indexrelid)
    LOOP
        EXECUTE format('DROP INDEX IF EXISTS public.%I', r.idxname);
        RAISE NOTICE 'Dropped unique index %', r.idxname;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. whatsapp_settings & genieacs_settings (tabel key-value)
--    Sebelumnya UNIQUE(setting_key) global -> menjadi UNIQUE(tenant_id, setting_key)
--    sehingga setiap tenant memiliki tepat 1 baris per kunci konfigurasi.
-- ------------------------------------------------------------------------------
SELECT public._drop_single_column_unique('whatsapp_settings', 'setting_key');
ALTER TABLE public.whatsapp_settings DROP CONSTRAINT IF EXISTS whatsapp_settings_tenant_key_uq;
ALTER TABLE public.whatsapp_settings
    ADD CONSTRAINT whatsapp_settings_tenant_key_uq UNIQUE (tenant_id, setting_key);

SELECT public._drop_single_column_unique('genieacs_settings', 'setting_key');
ALTER TABLE public.genieacs_settings DROP CONSTRAINT IF EXISTS genieacs_settings_tenant_key_uq;
ALTER TABLE public.genieacs_settings
    ADD CONSTRAINT genieacs_settings_tenant_key_uq UNIQUE (tenant_id, setting_key);

-- ------------------------------------------------------------------------------
-- 5. app_settings (singleton) -> UNIQUE(tenant_id)
--    Jika ada baris duplikat per tenant, baris terbaru dipertahankan dan sisanya
--    dipindahkan ke tabel backup (bukan dihapus permanen -> Zero Data Loss).
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_settings_legacy_backup
    (LIKE public.app_settings INCLUDING DEFAULTS);
ALTER TABLE public.app_settings_legacy_backup
    ADD COLUMN IF NOT EXISTS backed_up_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.app_settings_legacy_backup ENABLE ROW LEVEL SECURITY; -- hanya service_role

WITH ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY tenant_id
               ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id
           ) AS rn
    FROM public.app_settings
),
moved AS (
    DELETE FROM public.app_settings s
    USING ranked r
    WHERE s.id = r.id AND r.rn > 1
    RETURNING s.*
)
INSERT INTO public.app_settings_legacy_backup
SELECT m.*, NOW() FROM moved m;

ALTER TABLE public.app_settings DROP CONSTRAINT IF EXISTS app_settings_tenant_uq;
ALTER TABLE public.app_settings
    ADD CONSTRAINT app_settings_tenant_uq UNIQUE (tenant_id);

-- ------------------------------------------------------------------------------
-- 6. Kode pelanggan (profiles.idpl): UNIQUE global -> UNIQUE(tenant_id, idpl)
-- ------------------------------------------------------------------------------
SELECT public._drop_single_column_unique('profiles', 'idpl');
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_tenant_idpl_uq;
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_tenant_idpl_uq UNIQUE (tenant_id, idpl);

-- Bersihkan helper internal
DROP FUNCTION IF EXISTS public._drop_single_column_unique(TEXT, TEXT);

SELECT 'Fase 2 selesai: tenant_id diinjeksikan, data lama dipetakan ke Default Tenant.' AS result;
