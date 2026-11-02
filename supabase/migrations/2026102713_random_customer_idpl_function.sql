-- ==============================================================================
-- FASE 13: Fungsi Generator ID Pelanggan Acak 5 Karakter (2 Huruf + 3 Angka)
-- ==============================================================================
-- Format: 2 Huruf Kapital Acak + 3 Angka Acak (contoh: UD417, AK208, RZ954)
-- Keuntungan:
-- 1. Ringkas (5 karakter), mudah dihafal pelanggan dan muat di struk kasir thermal 58mm.
-- 2. Anti-bentrok dengan 676.000 kombinasi unik per tenant.
-- 3. Non-sequential (pelanggan tidak bisa menebak jumlah total pelanggan mitra).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.generate_customer_idpl(p_tenant_id UUID DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant UUID := COALESCE(p_tenant_id, public.get_my_tenant_id());
    v_letters TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ'; -- 24 huruf tanpa I & O
    v_idpl TEXT;
    v_exists BOOLEAN;
    v_l1 CHAR(1);
    v_l2 CHAR(1);
    v_num INTEGER;
BEGIN
    LOOP
        v_l1 := substr(v_letters, floor(random() * length(v_letters) + 1)::int, 1);
        v_l2 := substr(v_letters, floor(random() * length(v_letters) + 1)::int, 1);
        v_num := floor(random() * 1000)::int;
        v_idpl := v_l1 || v_l2 || lpad(v_num::text, 3, '0');

        SELECT EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE idpl = v_idpl 
              AND (v_tenant IS NULL OR tenant_id = v_tenant)
        ) INTO v_exists;

        EXIT WHEN NOT v_exists;
    END LOOP;

    RETURN v_idpl;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_customer_idpl(UUID) TO authenticated, service_role;

