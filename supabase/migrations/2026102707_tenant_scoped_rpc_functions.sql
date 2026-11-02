-- ==============================================================================
-- FASE 4B (tambahan): Tenant-Scoped RPC / Stored Functions
-- ==============================================================================
-- Seluruh RPC lama di Database.sql bersifat SECURITY DEFINER sehingga MELEWATI
-- RLS. Tanpa patch ini, admin Tenant A dapat membaca data Tenant B via
-- supabase.rpc('get_all_customers'), get_dashboard_stats, dll.
-- File ini meng-CREATE OR REPLACE fungsi-fungsi tersebut (signature sama,
-- sehingga frontend tidak perlu diubah) dengan filter tenant_id.
-- Idempotent: aman dijalankan berulang kali.
-- ==============================================================================

-- Helper: wajib admin/super admin, atau konteks service
CREATE OR REPLACE FUNCTION public._assert_admin()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.is_service_context() OR public.is_super_admin() OR public.is_tenant_admin() THEN
        RETURN;
    END IF;
    RAISE EXCEPTION 'Akses ditolak: hanya admin yang dapat menjalankan fungsi ini.'
        USING ERRCODE = '42501';
END;
$$;

-- Helper: filter tenant. TRUE jika baris boleh dilihat pemanggil.
CREATE OR REPLACE FUNCTION public._tenant_visible(p_tenant_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_service_context()
        OR public.is_super_admin()
        OR p_tenant_id = public.get_my_tenant_id();
$$;

-- ------------------------------------------------------------------------------
-- get_user_email: hanya diri sendiri / sesama tenant (admin) / super admin
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    user_email TEXT;
    v_target_tenant UUID;
BEGIN
    IF NOT (public.is_service_context() OR public.is_super_admin() OR user_id = auth.uid()) THEN
        SELECT tenant_id INTO v_target_tenant FROM public.profiles WHERE id = user_id;
        IF NOT public.is_tenant_admin() OR v_target_tenant IS DISTINCT FROM public.get_my_tenant_id() THEN
            RETURN '';
        END IF;
    END IF;

    SELECT email INTO user_email FROM auth.users WHERE id = user_id;
    RETURN COALESCE(user_email, '');
END;
$$;

-- ------------------------------------------------------------------------------
-- broadcast_to_all_admins: hanya admin di tenant pemanggil
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.broadcast_to_all_admins(
    notification_type TEXT,
    title TEXT,
    message TEXT,
    data JSONB DEFAULT '{}'::jsonb,
    url TEXT DEFAULT NULL
) RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant UUID := public.get_my_tenant_id();
    admin_count INTEGER := 0;
BEGIN
    IF v_tenant IS NULL THEN
        RAISE EXCEPTION 'Tenant tidak diketahui.';
    END IF;

    INSERT INTO public.notifications (tenant_id, title, body, recipient_role, url, type, data)
    VALUES (v_tenant, title, message, 'ADMIN', url, notification_type, data);

    SELECT COUNT(*) INTO admin_count
    FROM public.profiles
    WHERE tenant_id = v_tenant AND public.normalize_role(role) = 'admin';

    RETURN 'Notification sent to ' || admin_count || ' admins';
END;
$$;

-- ------------------------------------------------------------------------------
-- cleanup_old_notifications: service/super admin = semua; admin = tenant sendiri
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_old_notifications(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    PERFORM public._assert_admin();

    DELETE FROM public.notifications
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL
      AND public._tenant_visible(tenant_id);

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- ------------------------------------------------------------------------------
-- create_monthly_invoices_v3
--   - Dipanggil admin  : hanya tenant admin tsb
--   - Dipanggil cron / service / super admin : semua tenant yang aktif
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_monthly_invoices_v3(
    p_month INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    target_invoice_period TEXT;
    created_invoices_count INTEGER := 0;
    customer_record RECORD;
    month_name TEXT;
    target_date DATE;
    target_m INTEGER;
    target_y INTEGER;
    v_all_tenants BOOLEAN;
    v_my_tenant UUID;
BEGIN
    PERFORM public._assert_admin();

    v_all_tenants := public.is_service_context() OR public.is_super_admin();
    v_my_tenant := public.get_my_tenant_id();

    IF NOT v_all_tenants AND NOT public.is_tenant_active(v_my_tenant) THEN
        RETURN jsonb_build_object('status', 'error',
            'message', 'Masa aktif langganan SaaS Anda telah berakhir. Silakan perpanjang langganan.');
    END IF;

    target_date := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
    target_m := COALESCE(p_month, EXTRACT(MONTH FROM target_date)::INTEGER);
    target_y := COALESCE(p_year, EXTRACT(YEAR FROM target_date)::INTEGER);

    SELECT CASE target_m
        WHEN 1 THEN 'Januari' WHEN 2 THEN 'Februari' WHEN 3 THEN 'Maret'
        WHEN 4 THEN 'April' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Juni'
        WHEN 7 THEN 'Juli' WHEN 8 THEN 'Agustus' WHEN 9 THEN 'September'
        WHEN 10 THEN 'Oktober' WHEN 11 THEN 'November' WHEN 12 THEN 'Desember'
    END INTO month_name;

    target_invoice_period := month_name || ' ' || target_y;

    FOR customer_record IN
        SELECT prof.id AS customer_id,
               prof.tenant_id AS customer_tenant_id,
               pack.price AS customer_price,
               pack.id AS customer_package_id
        FROM public.profiles prof
        JOIN public.packages pack
          ON prof.package_id = pack.id
         AND pack.tenant_id = prof.tenant_id
        WHERE public.normalize_role(prof.role) = 'pelanggan'
          AND prof.status = 'AKTIF'
          AND (
              (v_all_tenants AND public.is_tenant_active(prof.tenant_id))
              OR (NOT v_all_tenants AND prof.tenant_id = v_my_tenant)
          )
          AND NOT EXISTS (
              SELECT 1 FROM public.invoices inv
              WHERE inv.customer_id = prof.id
                AND inv.invoice_period = target_invoice_period
          )
    LOOP
        INSERT INTO public.invoices (
            tenant_id, customer_id, package_id, invoice_period,
            amount, total_due, status, due_date
        ) VALUES (
            customer_record.customer_tenant_id,
            customer_record.customer_id,
            customer_record.customer_package_id,
            target_invoice_period,
            customer_record.customer_price,
            customer_record.customer_price,
            'unpaid',
            (target_y || '-' || LPAD(target_m::TEXT, 2, '0') || '-20')::DATE
        );
        created_invoices_count := created_invoices_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Generated ' || created_invoices_count || ' invoices for ' || target_invoice_period,
        'count', created_invoices_count,
        'period', target_invoice_period
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

-- ------------------------------------------------------------------------------
-- get_all_customers (admin, tenant sendiri)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_all_customers(
    p_filter TEXT DEFAULT 'all',
    p_search_term TEXT DEFAULT ''
) RETURNS TABLE(
    id UUID,
    idpl TEXT,
    full_name TEXT,
    address TEXT,
    gender TEXT,
    whatsapp_number TEXT,
    role TEXT,
    photo_url TEXT,
    status public.customer_status,
    installation_date DATE,
    device_type TEXT,
    ip_static_pppoe TEXT,
    created_at TIMESTAMPTZ,
    churn_date DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public._assert_admin();

    RETURN QUERY
    SELECT
        p.id, p.idpl, p.full_name, p.address, p.gender, p.whatsapp_number,
        p.role, p.photo_url, p.status, p.installation_date, p.device_type,
        p.ip_static_pppoe, p.created_at, p.churn_date
    FROM public.profiles p
    WHERE public.normalize_role(p.role) = 'pelanggan'
      AND public._tenant_visible(p.tenant_id)
      AND (
          p_filter = 'all'
          OR (p_filter = 'active' AND p.status = 'AKTIF')
          OR (p_filter = 'inactive' AND p.status = 'NONAKTIF')
      )
      AND (
          p_search_term = ''
          OR p.full_name ILIKE '%' || p_search_term || '%'
          OR p.idpl ILIKE '%' || p_search_term || '%'
          OR p.address ILIKE '%' || p_search_term || '%'
          OR p.whatsapp_number ILIKE '%' || p_search_term || '%'
      )
    ORDER BY p.created_at DESC;
END;
$$;

-- ------------------------------------------------------------------------------
-- get_dashboard_stats (admin, tenant sendiri)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(
    p_month INTEGER DEFAULT 0,
    p_year INTEGER DEFAULT (EXTRACT(YEAR FROM CURRENT_DATE))::INTEGER
) RETURNS TABLE(
    total_revenue NUMERIC,
    total_expenses NUMERIC,
    profit NUMERIC,
    active_customers INTEGER,
    inactive_customers INTEGER,
    unpaid_invoices_count INTEGER,
    paid_invoices_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_revenue NUMERIC := 0;
    v_total_expenses NUMERIC := 0;
    v_active_customers INTEGER := 0;
    v_inactive_customers INTEGER := 0;
    v_unpaid_invoices_count INTEGER := 0;
    v_paid_invoices_count INTEGER := 0;
BEGIN
    PERFORM public._assert_admin();

    SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_revenue
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND (p_month = 0 OR EXTRACT(MONTH FROM COALESCE(last_payment_date, paid_at, created_at)) = p_month)
      AND (p_year = 0 OR EXTRACT(YEAR FROM COALESCE(last_payment_date, paid_at, created_at)) = p_year)
      AND amount_paid > 0;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.expenses
    WHERE public._tenant_visible(tenant_id)
      AND (p_month = 0 OR EXTRACT(MONTH FROM expense_date) = p_month)
      AND (p_year = 0 OR EXTRACT(YEAR FROM expense_date) = p_year);

    SELECT
        COUNT(CASE WHEN status = 'AKTIF' THEN 1 END),
        COUNT(CASE WHEN status = 'NONAKTIF' THEN 1 END)
    INTO v_active_customers, v_inactive_customers
    FROM public.profiles
    WHERE public.normalize_role(role) = 'pelanggan'
      AND public._tenant_visible(tenant_id);

    SELECT
        COUNT(CASE WHEN status = 'unpaid' THEN 1 END),
        COUNT(CASE WHEN status = 'paid' THEN 1 END)
    INTO v_unpaid_invoices_count, v_paid_invoices_count
    FROM public.invoices
    WHERE public._tenant_visible(tenant_id)
      AND (p_month = 0 OR EXTRACT(MONTH FROM created_at) = p_month)
      AND (p_year = 0 OR EXTRACT(YEAR FROM created_at) = p_year);

    RETURN QUERY SELECT
        v_total_revenue,
        v_total_expenses,
        v_total_revenue - v_total_expenses,
        v_active_customers,
        v_inactive_customers,
        v_unpaid_invoices_count,
        v_paid_invoices_count;
END;
$$;

-- ------------------------------------------------------------------------------
-- get_dashboard_charts_data (admin, tenant sendiri)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_dashboard_charts_data(p_months INTEGER DEFAULT 6)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    chart_data JSONB := '[]'::jsonb;
    month_cursor DATE;
    start_date DATE;
    m_name TEXT;
    m_num INTEGER;
    y_num INTEGER;
    rev NUMERIC;
    exp NUMERIC;
BEGIN
    PERFORM public._assert_admin();

    start_date := (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL)::DATE;

    FOR i IN 0..(p_months - 1) LOOP
        month_cursor := (start_date + (i || ' months')::INTERVAL)::DATE;
        m_num := EXTRACT(MONTH FROM month_cursor)::INTEGER;
        y_num := EXTRACT(YEAR FROM month_cursor)::INTEGER;

        SELECT CASE m_num
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Agu' WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Okt' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Des'
        END INTO m_name;

        SELECT COALESCE(SUM(amount_paid), 0) INTO rev
        FROM public.invoices
        WHERE public._tenant_visible(tenant_id)
          AND EXTRACT(MONTH FROM COALESCE(last_payment_date, paid_at, created_at)) = m_num
          AND EXTRACT(YEAR FROM COALESCE(last_payment_date, paid_at, created_at)) = y_num;

        SELECT COALESCE(SUM(amount), 0) INTO exp
        FROM public.expenses
        WHERE public._tenant_visible(tenant_id)
          AND EXTRACT(MONTH FROM expense_date) = m_num
          AND EXTRACT(YEAR FROM expense_date) = y_num;

        chart_data := chart_data || jsonb_build_object(
            'period', m_name || ' ' || y_num,
            'revenue', rev,
            'expense', exp,
            'profit', rev - exp
        );
    END LOOP;

    RETURN chart_data;
END;
$$;

-- ------------------------------------------------------------------------------
-- get_invoices_with_payment_info
--   admin: seluruh tagihan tenant | pelanggan: hanya tagihan miliknya
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_invoices_with_payment_info(
    p_status TEXT DEFAULT 'all',
    p_customer_id UUID DEFAULT NULL
) RETURNS TABLE(
    id UUID,
    customer_id UUID,
    customer_name TEXT,
    whatsapp_number TEXT,
    invoice_period TEXT,
    total_due NUMERIC,
    amount_paid NUMERIC,
    remaining_amount NUMERIC,
    status public.invoice_status,
    due_date DATE,
    last_payment_date TIMESTAMPTZ,
    payment_count INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_admin BOOLEAN := public.is_service_context() OR public.is_super_admin() OR public.is_tenant_admin();
BEGIN
    RETURN QUERY
    SELECT
        inv.id,
        inv.customer_id,
        p.full_name AS customer_name,
        p.whatsapp_number,
        inv.invoice_period,
        COALESCE(inv.total_due, inv.amount) AS total_due,
        COALESCE(inv.amount_paid, 0) AS amount_paid,
        (COALESCE(inv.total_due, inv.amount) - COALESCE(inv.amount_paid, 0)) AS remaining_amount,
        inv.status,
        inv.due_date,
        inv.last_payment_date,
        COALESCE(jsonb_array_length(inv.payment_history), 0)::INTEGER AS payment_count,
        inv.created_at
    FROM public.invoices inv
    JOIN public.profiles p ON inv.customer_id = p.id
    WHERE public._tenant_visible(inv.tenant_id)
      AND (v_is_admin OR inv.customer_id = auth.uid())
      AND (p_customer_id IS NULL OR inv.customer_id = p_customer_id)
      AND (
          p_status = 'all'
          OR (p_status = 'paid' AND inv.status = 'paid')
          OR (p_status = 'unpaid' AND inv.status IN ('unpaid', 'partially_paid'))
          OR (p_status = 'overdue' AND inv.status = 'overdue')
      )
    ORDER BY inv.created_at DESC;
END;
$$;

-- ------------------------------------------------------------------------------
-- get_payment_history
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_payment_history(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    history JSONB;
    v_is_admin BOOLEAN := public.is_service_context() OR public.is_super_admin() OR public.is_tenant_admin();
BEGIN
    SELECT COALESCE(payment_history, '[]'::jsonb) INTO history
    FROM public.invoices
    WHERE id = p_invoice_id
      AND public._tenant_visible(tenant_id)
      AND (v_is_admin OR customer_id = auth.uid());

    RETURN COALESCE(history, '[]'::jsonb);
END;
$$;

-- ------------------------------------------------------------------------------
-- process_installment_payment (admin, tenant sendiri)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_installment_payment(
    p_invoice_id UUID,
    p_payment_amount NUMERIC,
    p_admin_name TEXT,
    p_payment_method TEXT DEFAULT 'cash',
    p_note TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_invoice RECORD;
    v_total_due NUMERIC;
    v_new_amount_paid NUMERIC;
    v_new_remaining NUMERIC;
    v_new_status public.invoice_status;
    new_entry JSONB;
    current_history JSONB;
BEGIN
    PERFORM public._assert_admin();

    SELECT * INTO current_invoice
    FROM public.invoices
    WHERE id = p_invoice_id
      AND public._tenant_visible(tenant_id)
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tagihan tidak ditemukan');
    END IF;

    IF current_invoice.status = 'paid' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tagihan sudah lunas');
    END IF;

    IF p_payment_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Jumlah pembayaran harus lebih dari 0');
    END IF;

    v_total_due := COALESCE(current_invoice.total_due, current_invoice.amount);
    v_new_amount_paid := COALESCE(current_invoice.amount_paid, 0) + p_payment_amount;
    v_new_remaining := v_total_due - v_new_amount_paid;

    IF v_new_remaining < 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Pembayaran melebihi sisa tagihan');
    END IF;

    IF v_new_remaining = 0 THEN
        v_new_status := 'paid';
    ELSE
        v_new_status := 'partially_paid';
    END IF;

    new_entry := jsonb_build_object(
        'payment_id', gen_random_uuid(),
        'amount', p_payment_amount,
        'paid_at', NOW(),
        'processed_by', p_admin_name,
        'payment_method', p_payment_method,
        'note', p_note,
        'remaining_after', v_new_remaining
    );

    current_history := COALESCE(current_invoice.payment_history, '[]'::jsonb) || jsonb_build_array(new_entry);

    UPDATE public.invoices
    SET amount_paid = v_new_amount_paid,
        status = v_new_status,
        last_payment_date = NOW(),
        paid_at = CASE WHEN v_new_status = 'paid' THEN NOW() ELSE paid_at END,
        payment_method = p_payment_method,
        payment_history = current_history
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Pembayaran berhasil diproses',
        'status', v_new_status,
        'amount_paid', v_new_amount_paid,
        'remaining_amount', v_new_remaining
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- Notifikasi: count / list / mark read — dibatasi tenant & user sendiri
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(user_id_param UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    unread_count INTEGER;
    u_role TEXT;
    u_tenant UUID;
BEGIN
    IF NOT public.is_service_context() AND user_id_param IS DISTINCT FROM auth.uid() THEN
        RETURN 0;
    END IF;

    SELECT public.normalize_role(role), tenant_id INTO u_role, u_tenant
    FROM public.profiles WHERE id = user_id_param;

    SELECT COUNT(*)::INTEGER INTO unread_count
    FROM public.notifications n
    WHERE n.tenant_id IS NOT DISTINCT FROM u_tenant
      AND (n.recipient_user_id = user_id_param
           OR (public.normalize_role(n.recipient_role) = u_role AND n.recipient_user_id IS NULL))
      AND NOT EXISTS (
          SELECT 1 FROM public.notification_reads nr
          WHERE nr.notification_id = n.id AND nr.user_id = user_id_param
      );

    RETURN COALESCE(unread_count, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_notifications(user_id_param UUID DEFAULT NULL)
RETURNS TABLE(
    id UUID,
    title TEXT,
    body TEXT,
    url TEXT,
    created_at TIMESTAMPTZ,
    is_read BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    target_user UUID;
    u_role TEXT;
    u_tenant UUID;
BEGIN
    target_user := COALESCE(user_id_param, auth.uid());

    IF NOT public.is_service_context() AND target_user IS DISTINCT FROM auth.uid() THEN
        RETURN;
    END IF;

    SELECT public.normalize_role(p.role), p.tenant_id INTO u_role, u_tenant
    FROM public.profiles p WHERE p.id = target_user;

    RETURN QUERY
    SELECT
        n.id, n.title, n.body, n.url, n.created_at,
        EXISTS (
            SELECT 1 FROM public.notification_reads nr
            WHERE nr.notification_id = n.id AND nr.user_id = target_user
        ) AS is_read
    FROM public.notifications n
    WHERE n.tenant_id IS NOT DISTINCT FROM u_tenant
      AND (n.recipient_user_id = target_user
           OR (public.normalize_role(n.recipient_role) = u_role AND n.recipient_user_id IS NULL))
    ORDER BY n.created_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(
    notification_id_param UUID,
    user_id_param UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_service_context() AND user_id_param IS DISTINCT FROM auth.uid() THEN
        RETURN FALSE;
    END IF;

    -- Pastikan notifikasi berada di tenant yang sama dengan user
    IF NOT EXISTS (
        SELECT 1 FROM public.notifications n
        JOIN public.profiles p ON p.id = user_id_param
        WHERE n.id = notification_id_param
          AND n.tenant_id IS NOT DISTINCT FROM p.tenant_id
    ) THEN
        RETURN FALSE;
    END IF;

    INSERT INTO public.notification_reads (notification_id, user_id, read_at)
    VALUES (notification_id_param, user_id_param, NOW())
    ON CONFLICT (notification_id, user_id) DO UPDATE SET read_at = NOW();
    RETURN TRUE;
END;
$$;

-- Catatan: add_payment_notification, send_admin_login_notification,
-- send_customer_added_notification, send_invoice_creation_notification,
-- send_payment_notification, dan log_admin_activity tidak perlu diubah:
-- INSERT ke notifications otomatis mendapat tenant_id dari DEFAULT
-- public.get_my_tenant_id() / trigger notifications_set_tenant.

REVOKE ALL ON FUNCTION public._assert_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._tenant_visible(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public._assert_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._tenant_visible(UUID) TO authenticated, service_role;

SELECT 'Fase 4B selesai: seluruh RPC SECURITY DEFINER kini terisolasi per tenant.' AS result;
