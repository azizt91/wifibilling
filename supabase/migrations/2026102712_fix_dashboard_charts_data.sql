-- ==============================================================================
-- FASE 12: Fix RPC get_dashboard_charts_data (Chart Dashboard Multi-Tenant)
-- ==============================================================================
-- Masalah sebelumnya: RPC get_dashboard_charts_data hanya mengembalikan array objek
-- period/revenue/expense/profit, sedangkan dashboard.js & Chart.js membutuhkan objek
-- lengkap: revenue_chart, payment_status_chart, customer_growth_chart, dan customer_total_chart.
-- Akibatnya, keempat grafik di dashboard tampil kosong/tidak ter-render.
--
-- Solusi:
-- Mengembalikan struktur JSONB lengkap yang sesuai dengan Chart.js di dashboard.js,
-- dengan isolasi multi-tenant ketat (_tenant_visible).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_dashboard_charts_data(p_months INTEGER DEFAULT 6)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    labels_data JSONB := '[]'::jsonb;
    revenue_data JSONB := '[]'::jsonb;
    expenses_data JSONB := '[]'::jsonb;
    profit_data JSONB := '[]'::jsonb;
    customer_growth_new JSONB := '[]'::jsonb;
    customer_growth_churn JSONB := '[]'::jsonb;
    customer_total_data JSONB := '[]'::jsonb;
    
    start_date DATE;
    month_cursor DATE;
    m_name TEXT;
    m_num INTEGER;
    y_num INTEGER;
    m_start TIMESTAMPTZ;
    m_end TIMESTAMPTZ;
    
    rev NUMERIC;
    exp NUMERIC;
    new_cust INTEGER;
    churn_cust INTEGER;
    cum_active INTEGER;
    
    paid_count INTEGER := 0;
    partially_paid_count INTEGER := 0;
    unpaid_count INTEGER := 0;
    total_inv INTEGER := 0;
BEGIN
    PERFORM public._assert_admin();

    -- Ambil rentang waktu p_months bulan terakhir
    start_date := (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL)::DATE;

    FOR i IN 0..(p_months - 1) LOOP
        month_cursor := (start_date + (i || ' months')::INTERVAL)::DATE;
        m_num := EXTRACT(MONTH FROM month_cursor)::INTEGER;
        y_num := EXTRACT(YEAR FROM month_cursor)::INTEGER;
        m_start := DATE_TRUNC('month', month_cursor);
        m_end := (m_start + INTERVAL '1 month');

        SELECT CASE m_num
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Agu' WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Okt' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Des'
        END INTO m_name;

        labels_data := labels_data || to_jsonb(m_name || ' ' || y_num);

        -- 1. Pendapatan (invoices milik tenant)
        SELECT COALESCE(SUM(amount_paid), 0) INTO rev
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id)
          AND (
              (last_payment_date >= m_start AND last_payment_date < m_end)
              OR (last_payment_date IS NULL AND paid_at >= m_start AND paid_at < m_end)
              OR (last_payment_date IS NULL AND paid_at IS NULL AND created_at >= m_start AND created_at < m_end AND status = 'paid')
          );

        IF rev = 0 THEN
            SELECT COALESCE(SUM(amount_paid), 0) INTO rev
            FROM public.invoices
            WHERE public._tenant_visible(tenant_id)
              AND status IN ('paid', 'partially_paid')
              AND created_at >= m_start AND created_at < m_end;
        END IF;

        revenue_data := revenue_data || to_jsonb(rev);

        -- 2. Pengeluaran (expenses milik tenant)
        SELECT COALESCE(SUM(amount), 0) INTO exp
        FROM public.expenses
        WHERE public._tenant_visible(tenant_id)
          AND expense_date >= month_cursor 
          AND expense_date < (month_cursor + INTERVAL '1 month')::DATE;

        expenses_data := expenses_data || to_jsonb(exp);
        profit_data := profit_data || to_jsonb(rev - exp);

        -- 3. Pertumbuhan Pelanggan Baru & Berhenti di bulan ini
        SELECT COUNT(*)::INTEGER INTO new_cust
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND (
              (installation_date >= month_cursor AND installation_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (installation_date IS NULL AND created_at >= m_start AND created_at < m_end)
          );
        customer_growth_new := customer_growth_new || to_jsonb(new_cust);

        SELECT COUNT(*)::INTEGER INTO churn_cust
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND status = 'NONAKTIF'
          AND (
              (churn_date >= month_cursor AND churn_date < (month_cursor + INTERVAL '1 month')::DATE)
              OR (churn_date IS NULL AND updated_at >= m_start AND updated_at < m_end)
          );
        customer_growth_churn := customer_growth_churn || to_jsonb(churn_cust);

        -- 4. Total Pelanggan Aktif Kumulatif sampai akhir bulan ini
        SELECT COUNT(*)::INTEGER INTO cum_active
        FROM public.profiles
        WHERE public._tenant_visible(tenant_id)
          AND public.normalize_role(role) = 'pelanggan'
          AND status = 'AKTIF'
          AND created_at < m_end;
        customer_total_data := customer_total_data || to_jsonb(cum_active);

    END LOOP;

    -- 5. Status Pembayaran Bulan Ini (atau keseluruhan tagihan jika bulan ini belum ada)
    SELECT 
        COUNT(CASE WHEN status = 'paid' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status = 'partially_paid' THEN 1 END)::INTEGER,
        COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END)::INTEGER
    INTO paid_count, partially_paid_count, unpaid_count
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE);

    total_inv := paid_count + partially_paid_count + unpaid_count;
    IF total_inv = 0 THEN
        SELECT 
            COUNT(CASE WHEN status = 'paid' THEN 1 END)::INTEGER,
            COUNT(CASE WHEN status = 'partially_paid' THEN 1 END)::INTEGER,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END)::INTEGER
        INTO paid_count, partially_paid_count, unpaid_count
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id);
    END IF;

    RETURN jsonb_build_object(
        'revenue_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Pendapatan',
                    'data', revenue_data,
                    'borderColor', '#10B981',
                    'backgroundColor', 'rgba(16, 185, 129, 0.1)',
                    'tension', 0.4,
                    'fill', true
                ),
                jsonb_build_object(
                    'label', 'Pengeluaran',
                    'data', expenses_data,
                    'borderColor', '#EF4444',
                    'backgroundColor', 'rgba(239, 68, 68, 0.1)',
                    'tension', 0.4,
                    'fill', true
                ),
                jsonb_build_object(
                    'label', 'Profit',
                    'data', profit_data,
                    'borderColor', '#6366F1',
                    'backgroundColor', 'rgba(99, 102, 241, 0.1)',
                    'tension', 0.4,
                    'fill', true
                )
            )
        ),
        'payment_status_chart', jsonb_build_object(
            'labels', jsonb_build_array('Lunas', 'Cicilan', 'Belum Bayar'),
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'data', jsonb_build_array(paid_count, partially_paid_count, unpaid_count),
                    'backgroundColor', jsonb_build_array('#10B981', '#F59E0B', '#EF4444'),
                    'borderColor', jsonb_build_array('#059669', '#D97706', '#DC2626'),
                    'borderWidth', 2
                )
            )
        ),
        'customer_growth_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Pelanggan Baru',
                    'data', customer_growth_new,
                    'backgroundColor', '#10B981',
                    'borderColor', '#059669',
                    'borderWidth', 2,
                    'borderRadius', 4
                ),
                jsonb_build_object(
                    'label', 'Pelanggan Berhenti',
                    'data', customer_growth_churn,
                    'backgroundColor', '#EF4444',
                    'borderColor', '#DC2626',
                    'borderWidth', 2,
                    'borderRadius', 4
                )
            )
        ),
        'customer_total_chart', jsonb_build_object(
            'labels', labels_data,
            'datasets', jsonb_build_array(
                jsonb_build_object(
                    'label', 'Total Pelanggan Aktif',
                    'data', customer_total_data,
                    'borderColor', '#8B5CF6',
                    'backgroundColor', 'rgba(139, 92, 246, 0.1)',
                    'tension', 0.4,
                    'fill', true
                )
            )
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dashboard_charts_data(INTEGER) TO authenticated, service_role;

