-- ============================================================================
-- REMOVE EMAIL CONFIRMATION REQUIREMENTS
-- ============================================================================

-- Voucher insert policy no longer requires email_confirmed JWT claim.
DROP POLICY IF EXISTS "Users can insert own vouchers" ON public.vouchers;

CREATE POLICY "Users can insert own vouchers"
  ON public.vouchers FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
  );

-- Submission validation without email confirmation requirement.
CREATE OR REPLACE FUNCTION public.validate_voucher_submission_hardening()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.enforce_daily_limit(NEW.user_id, 'submission', 10);

  IF EXISTS (
    SELECT 1
    FROM public.vouchers v
    WHERE v.user_id = NEW.user_id
      AND LOWER(v.merchant_name) = LOWER(NEW.merchant_name)
      AND v.created_at > NOW() - INTERVAL '1 hour'
      AND v.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'You can only submit one voucher per merchant per hour';
  END IF;

  RETURN NEW;
END;
$$;

-- Usage validation without email confirmation requirement.
CREATE OR REPLACE FUNCTION public.validate_voucher_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  voucher_max_uses INTEGER;
  voucher_use_count INTEGER;
  voucher_deleted_at TIMESTAMPTZ;
  voucher_is_active BOOLEAN;
BEGIN
  PERFORM public.enforce_daily_limit(NEW.user_id, 'use', 10);

  SELECT v.max_uses, v.use_count, v.deleted_at, v.is_active
  INTO voucher_max_uses, voucher_use_count, voucher_deleted_at, voucher_is_active
  FROM public.vouchers v
  WHERE v.id = NEW.voucher_id;

  IF voucher_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'This voucher has been deleted';
  END IF;

  IF voucher_is_active IS FALSE THEN
    RAISE EXCEPTION 'This voucher is inactive';
  END IF;

  IF voucher_use_count >= voucher_max_uses THEN
    RAISE EXCEPTION 'This voucher has reached its maximum usage limit';
  END IF;

  RETURN NEW;
END;
$$;

-- Report validation without email confirmation requirement.
CREATE OR REPLACE FUNCTION public.validate_voucher_report_hardening()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  reporter_points INTEGER;
  reporter_created_at TIMESTAMPTZ;
  voucher_owner UUID;
BEGIN
  SELECT p.points, p.created_at
  INTO reporter_points, reporter_created_at
  FROM public.profiles p
  WHERE p.id = NEW.reporter_id;

  IF reporter_created_at > NOW() - INTERVAL '7 days' THEN
    RAISE EXCEPTION 'Account must be at least 7 days old to report vouchers';
  END IF;

  IF reporter_points < 20 THEN
    RAISE EXCEPTION 'At least 20 points are required to report vouchers';
  END IF;

  PERFORM public.enforce_daily_limit(NEW.reporter_id, 'report', 5);

  SELECT v.user_id INTO voucher_owner
  FROM public.vouchers v
  WHERE v.id = NEW.voucher_id;

  IF voucher_owner = NEW.reporter_id THEN
    RAISE EXCEPTION 'You cannot report your own voucher';
  END IF;

  RETURN NEW;
END;
$$;

-- Remove obsolete helper that depended on auth.users.email_confirmed_at.
DROP FUNCTION IF EXISTS public.is_email_confirmed(UUID);
