-- ============================================================================
-- ABUSE HARDENING
-- ============================================================================

-- 1) Schema additions for abuse controls
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_suspicious BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.vouchers
ADD COLUMN IF NOT EXISTS submission_rewarded BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS weighted_report_score NUMERIC(10,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.user_daily_activity (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_date DATE NOT NULL,
  voucher_submissions INTEGER NOT NULL DEFAULT 0,
  voucher_uses INTEGER NOT NULL DEFAULT 0,
  reports INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, activity_date)
);

CREATE TABLE IF NOT EXISTS public.voucher_pair_interactions (
  user_low UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_high UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  interaction_count INTEGER NOT NULL DEFAULT 0,
  last_interacted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_low, user_high),
  CHECK (user_low <> user_high)
);

CREATE INDEX IF NOT EXISTS idx_user_daily_activity_date
  ON public.user_daily_activity(activity_date);

CREATE INDEX IF NOT EXISTS idx_voucher_pair_interactions_last_interacted
  ON public.voucher_pair_interactions(last_interacted_at DESC);

-- 2) Utility functions
CREATE OR REPLACE FUNCTION public.is_account_mature(
  p_user_id UUID,
  p_min_age INTERVAL DEFAULT INTERVAL '24 hours'
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_user_id
      AND p.created_at <= NOW() - p_min_age
  );
$$;

CREATE OR REPLACE FUNCTION public.is_email_confirmed(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = p_user_id
      AND u.email_confirmed_at IS NOT NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.enforce_daily_limit(
  p_user_id UUID,
  p_action TEXT,
  p_limit INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_count INTEGER;
BEGIN
  IF p_action NOT IN ('submission', 'use', 'report') THEN
    RAISE EXCEPTION 'Unsupported daily activity action: %', p_action;
  END IF;

  WITH upsert AS (
    INSERT INTO public.user_daily_activity (
      user_id,
      activity_date,
      voucher_submissions,
      voucher_uses,
      reports,
      updated_at
    )
    VALUES (
      p_user_id,
      CURRENT_DATE,
      CASE WHEN p_action = 'submission' THEN 1 ELSE 0 END,
      CASE WHEN p_action = 'use' THEN 1 ELSE 0 END,
      CASE WHEN p_action = 'report' THEN 1 ELSE 0 END,
      NOW()
    )
    ON CONFLICT (user_id, activity_date)
    DO UPDATE
      SET voucher_submissions = public.user_daily_activity.voucher_submissions +
          CASE WHEN p_action = 'submission' THEN 1 ELSE 0 END,
          voucher_uses = public.user_daily_activity.voucher_uses +
          CASE WHEN p_action = 'use' THEN 1 ELSE 0 END,
          reports = public.user_daily_activity.reports +
          CASE WHEN p_action = 'report' THEN 1 ELSE 0 END,
          updated_at = NOW()
    RETURNING voucher_submissions, voucher_uses, reports
  )
  SELECT
    CASE
      WHEN p_action = 'submission' THEN voucher_submissions
      WHEN p_action = 'use' THEN voucher_uses
      ELSE reports
    END
  INTO current_count
  FROM upsert;

  IF current_count > p_limit THEN
    RAISE EXCEPTION 'Daily % limit reached (% per day)', p_action, p_limit;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_report_weight(p_reporter_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  reporter_points INTEGER;
  reporter_created_at TIMESTAMPTZ;
BEGIN
  SELECT p.points, p.created_at
  INTO reporter_points, reporter_created_at
  FROM public.profiles p
  WHERE p.id = p_reporter_id;

  IF reporter_created_at IS NULL OR reporter_created_at > NOW() - INTERVAL '7 days' THEN
    RETURN 0;
  END IF;

  IF reporter_points >= 200 THEN
    RETURN 2;
  ELSIF reporter_points >= 50 THEN
    RETURN 1.5;
  ELSIF reporter_points >= 20 THEN
    RETURN 1;
  END IF;

  RETURN 0.5;
END;
$$;

-- 3) Voucher submission controls
DROP POLICY IF EXISTS "Users can insert own vouchers" ON public.vouchers;

CREATE POLICY "Users can insert own vouchers"
  ON public.vouchers FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND COALESCE(auth.jwt() ->> 'email_confirmed', 'false') = 'true'
  );

CREATE OR REPLACE FUNCTION public.validate_voucher_submission_hardening()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_email_confirmed(NEW.user_id) THEN
    RAISE EXCEPTION 'Email must be verified before submitting vouchers';
  END IF;

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

DROP TRIGGER IF EXISTS before_voucher_insert_hardening ON public.vouchers;

CREATE TRIGGER before_voucher_insert_hardening
BEFORE INSERT ON public.vouchers
FOR EACH ROW
EXECUTE FUNCTION public.validate_voucher_submission_hardening();

-- Remove immediate submission points; award later on first real use.
DROP TRIGGER IF EXISTS after_voucher_insert ON public.vouchers;

-- 4) Voucher usage controls and anti-collusion scoring
CREATE OR REPLACE FUNCTION public.validate_voucher_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  voucher_max_uses INTEGER;
  voucher_use_count INTEGER;
  voucher_deleted_at TIMESTAMPTZ;
  voucher_is_active BOOLEAN;
BEGIN
  IF NOT public.is_email_confirmed(NEW.user_id) THEN
    RAISE EXCEPTION 'Email must be verified before using vouchers';
  END IF;

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

CREATE OR REPLACE FUNCTION public.handle_voucher_usage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  voucher_owner_id UUID;
  voucher_rewarded BOOLEAN;
  is_self_use BOOLEAN;
  pair_low UUID;
  pair_high UUID;
  pair_count INTEGER;
  user_reward INTEGER := 0;
  owner_reward INTEGER := 0;
BEGIN
  SELECT v.user_id, v.submission_rewarded
  INTO voucher_owner_id, voucher_rewarded
  FROM public.vouchers v
  WHERE v.id = NEW.voucher_id
  FOR UPDATE;

  is_self_use := (NEW.user_id = voucher_owner_id);

  IF is_self_use THEN
    UPDATE public.vouchers
    SET deleted_at = NOW(),
        updated_at = NOW(),
        use_count = use_count + 1
    WHERE id = NEW.voucher_id;

    RETURN NEW;
  END IF;

  pair_low := LEAST(NEW.user_id, voucher_owner_id);
  pair_high := GREATEST(NEW.user_id, voucher_owner_id);

  INSERT INTO public.voucher_pair_interactions (user_low, user_high, interaction_count, last_interacted_at)
  VALUES (pair_low, pair_high, 1, NOW())
  ON CONFLICT (user_low, user_high)
  DO UPDATE
    SET interaction_count = public.voucher_pair_interactions.interaction_count + 1,
        last_interacted_at = NOW()
  RETURNING interaction_count INTO pair_count;

  IF pair_count <= 3 THEN
    user_reward := 5;
    owner_reward := 2;
  ELSIF pair_count <= 5 THEN
    user_reward := 1;
    owner_reward := 1;
  END IF;

  IF user_reward > 0 AND public.is_account_mature(NEW.user_id, INTERVAL '24 hours') THEN
    UPDATE public.profiles
    SET points = points + user_reward,
        updated_at = NOW()
    WHERE id = NEW.user_id;
  END IF;

  IF owner_reward > 0 AND public.is_account_mature(voucher_owner_id, INTERVAL '24 hours') THEN
    UPDATE public.profiles
    SET points = points + owner_reward,
        updated_at = NOW()
    WHERE id = voucher_owner_id;
  END IF;

  IF voucher_rewarded = false AND public.is_account_mature(voucher_owner_id, INTERVAL '24 hours') THEN
    UPDATE public.profiles
    SET points = points + 10,
        updated_at = NOW()
    WHERE id = voucher_owner_id;

    UPDATE public.vouchers
    SET submission_rewarded = true,
        updated_at = NOW()
    WHERE id = NEW.voucher_id;
  END IF;

  UPDATE public.vouchers
  SET use_count = use_count + 1,
      updated_at = NOW()
  WHERE id = NEW.voucher_id;

  RETURN NEW;
END;
$$;

-- 5) Report hardening and weighted report score
CREATE OR REPLACE FUNCTION public.validate_voucher_report_hardening()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  reporter_points INTEGER;
  reporter_created_at TIMESTAMPTZ;
  voucher_owner UUID;
BEGIN
  IF NOT public.is_email_confirmed(NEW.reporter_id) THEN
    RAISE EXCEPTION 'Email must be verified before reporting vouchers';
  END IF;

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

DROP TRIGGER IF EXISTS before_voucher_report_insert_hardening ON public.voucher_reports;

CREATE TRIGGER before_voucher_report_insert_hardening
BEFORE INSERT ON public.voucher_reports
FOR EACH ROW
EXECUTE FUNCTION public.validate_voucher_report_hardening();

CREATE OR REPLACE FUNCTION public.increment_voucher_report_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  report_weight NUMERIC;
BEGIN
  report_weight := public.get_report_weight(NEW.reporter_id);

  UPDATE public.vouchers
  SET report_count = report_count + 1,
      weighted_report_score = weighted_report_score + report_weight,
      updated_at = NOW()
  WHERE id = NEW.voucher_id;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.deactivate_reported_vouchers()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.vouchers
  SET is_active = false,
      updated_at = NOW()
  WHERE is_active = true
    AND deleted_at IS NULL
    AND weighted_report_score >= 3;
END;
$$;

-- 6) Leaderboard integrity filters
CREATE OR REPLACE FUNCTION public.get_public_leaderboard(limit_count INTEGER DEFAULT 100)
RETURNS TABLE (
  id UUID,
  display_name TEXT,
  avatar_url TEXT,
  points INTEGER
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id,
    p.display_name,
    CASE WHEN p.show_profile_picture THEN p.avatar_url ELSE NULL END AS avatar_url,
    COALESCE(p.points, 0) AS points
  FROM public.profiles p
  WHERE p.created_at < NOW() - INTERVAL '24 hours'
    AND p.is_suspicious = false
  ORDER BY p.points DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(limit_count, 100));
$$;

REVOKE ALL ON FUNCTION public.get_public_leaderboard(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_leaderboard(INTEGER) TO anon, authenticated;
