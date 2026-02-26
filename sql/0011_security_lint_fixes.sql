-- ============================================================================
-- SECURITY LINTER FIXES
-- ============================================================================

-- 1) Enable RLS on public tables flagged by Supabase linter.
ALTER TABLE IF EXISTS public.user_daily_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.voucher_pair_interactions ENABLE ROW LEVEL SECURITY;

-- 2) Set immutable search_path for functions flagged by Supabase linter.
ALTER FUNCTION public.award_submission_points() SET search_path = public;
ALTER FUNCTION public.soft_delete_voucher(UUID, UUID) SET search_path = public;
ALTER FUNCTION public.deactivate_reported_vouchers() SET search_path = public;
