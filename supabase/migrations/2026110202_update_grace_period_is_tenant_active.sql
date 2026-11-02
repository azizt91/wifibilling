-- Migration: Update is_tenant_active to support 3-day grace period (locked on Day 4)
CREATE OR REPLACE FUNCTION public.is_tenant_active(check_tenant_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((
        SELECT t.subscription_status IN ('active', 'trial')
               AND (
                   t.subscription_expires_at IS NULL 
                   OR t.subscription_expires_at > (NOW() - INTERVAL '3 days')
               )
        FROM public.tenants t
        WHERE t.id = check_tenant_id
    ), FALSE);
$$;

