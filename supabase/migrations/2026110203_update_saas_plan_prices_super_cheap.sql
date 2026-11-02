-- Migration: Update SaaS plan prices to super cheap / accessible rates
-- Starter: Rp 10.000 / month (max 100 customers)
-- Pro: Rp 25.000 / month (max 500 customers)
-- Unlimited: Rp 50.000 / month (unlimited customers)

UPDATE public.saas_plans
SET price_monthly = 10000.00,
    updated_at = NOW()
WHERE slug = 'starter';

UPDATE public.saas_plans
SET price_monthly = 25000.00,
    updated_at = NOW()
WHERE slug = 'pro';

UPDATE public.saas_plans
SET price_monthly = 50000.00,
    updated_at = NOW()
WHERE slug = 'unlimited';

