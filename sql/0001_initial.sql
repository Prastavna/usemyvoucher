-- ============================================================================
-- TABLES
-- ============================================================================

-- 1. Profiles table (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  points INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_points ON profiles(points DESC);
CREATE INDEX idx_profiles_created_at ON profiles(created_at);

-- 2. Vouchers table
CREATE TABLE vouchers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  merchant_name TEXT NOT NULL,
  voucher_code TEXT NOT NULL,
  description TEXT,
  discount_value TEXT,
  expiry_date DATE,
  category TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  report_count INTEGER DEFAULT 0,
  use_count INTEGER DEFAULT 0,
  max_uses INTEGER DEFAULT 1,
  deleted_at TIMESTAMPTZ DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vouchers_user_id ON vouchers(user_id);
CREATE INDEX idx_vouchers_is_active ON vouchers(is_active);
CREATE INDEX idx_vouchers_report_count ON vouchers(report_count);
CREATE INDEX idx_vouchers_expiry_date ON vouchers(expiry_date);
CREATE INDEX idx_vouchers_created_at ON vouchers(created_at DESC);
CREATE INDEX idx_vouchers_use_count ON vouchers(use_count DESC);
CREATE INDEX idx_vouchers_deleted_at ON vouchers(deleted_at);

-- 3. Voucher reports table
CREATE TABLE voucher_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id UUID NOT NULL REFERENCES vouchers(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(voucher_id, reporter_id)
);

CREATE INDEX idx_voucher_reports_voucher_id ON voucher_reports(voucher_id);
CREATE INDEX idx_voucher_reports_reporter_id ON voucher_reports(reporter_id);

-- 4. Voucher views table
CREATE TABLE voucher_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id UUID NOT NULL REFERENCES vouchers(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(voucher_id, viewer_id)
);

CREATE INDEX idx_voucher_views_voucher_id ON voucher_views(voucher_id);
CREATE INDEX idx_voucher_views_viewer_id ON voucher_views(viewer_id);

-- 5. Voucher uses table
CREATE TABLE voucher_uses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id UUID NOT NULL REFERENCES vouchers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  used_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(voucher_id, user_id)
);

CREATE INDEX idx_voucher_uses_voucher_id ON voucher_uses(voucher_id);
CREATE INDEX idx_voucher_uses_user_id ON voucher_uses(user_id);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE voucher_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE voucher_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE voucher_uses ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Vouchers policies
CREATE POLICY "Authenticated users can view active non-deleted vouchers"
  ON vouchers FOR SELECT
  TO authenticated
  USING (is_active = true AND deleted_at IS NULL);

CREATE POLICY "Users can insert own vouchers"
  ON vouchers FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own vouchers"
  ON vouchers FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own vouchers"
  ON vouchers FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Voucher reports policies
CREATE POLICY "Users can view all reports"
  ON voucher_reports FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert reports"
  ON voucher_reports FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- Voucher views policies
CREATE POLICY "Users can view own views"
  ON voucher_views FOR SELECT
  TO authenticated
  USING (auth.uid() = viewer_id);

CREATE POLICY "Users can insert own views"
  ON voucher_views FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = viewer_id);

-- Voucher uses policies
CREATE POLICY "Users can view all uses"
  ON voucher_uses FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert own uses"
  ON voucher_uses FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- 1. Increment report count when a report is created
CREATE OR REPLACE FUNCTION increment_voucher_report_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE vouchers
  SET report_count = report_count + 1,
      updated_at = NOW()
  WHERE id = NEW.voucher_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_voucher_report_insert
AFTER INSERT ON voucher_reports
FOR EACH ROW
EXECUTE FUNCTION increment_voucher_report_count();

-- 2. Award points for voucher submission
CREATE OR REPLACE FUNCTION award_submission_points()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET points = points + 10,
      updated_at = NOW()
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_voucher_insert
AFTER INSERT ON vouchers
FOR EACH ROW
EXECUTE FUNCTION award_submission_points();

-- 3. Validate voucher usage before insert
CREATE OR REPLACE FUNCTION validate_voucher_usage()
RETURNS TRIGGER AS $$
DECLARE
  voucher_max_uses INTEGER;
  voucher_use_count INTEGER;
  voucher_deleted_at TIMESTAMPTZ;
BEGIN
  -- Get voucher details
  SELECT max_uses, use_count, deleted_at
  INTO voucher_max_uses, voucher_use_count, voucher_deleted_at
  FROM vouchers
  WHERE id = NEW.voucher_id;
  
  -- Check if voucher is soft deleted
  IF voucher_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'This voucher has been deleted';
  END IF;
  
  -- Check if voucher has reached max uses
  IF voucher_use_count >= voucher_max_uses THEN
    RAISE EXCEPTION 'This voucher has reached its maximum usage limit';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_voucher_use_insert
BEFORE INSERT ON voucher_uses
FOR EACH ROW
EXECUTE FUNCTION validate_voucher_usage();

-- 4. Handle voucher usage (points and soft delete for self-use)
CREATE OR REPLACE FUNCTION handle_voucher_usage()
RETURNS TRIGGER AS $$
DECLARE
  voucher_owner_id UUID;
  is_self_use BOOLEAN;
BEGIN
  -- Get the voucher owner
  SELECT user_id INTO voucher_owner_id
  FROM vouchers
  WHERE id = NEW.voucher_id;
  
  -- Check if this is self-usage
  is_self_use := (NEW.user_id = voucher_owner_id);
  
  IF is_self_use THEN
    -- Deduct the original 10 submission points
    UPDATE profiles
    SET points = GREATEST(points - 10, 0),
        updated_at = NOW()
    WHERE id = NEW.user_id;
    
    -- Soft delete the voucher
    UPDATE vouchers
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = NEW.voucher_id;
  ELSE
    -- Award 5 points to the user who used the code
    UPDATE profiles
    SET points = points + 5,
        updated_at = NOW()
    WHERE id = NEW.user_id;
    
    -- Award 2 bonus points to the voucher submitter
    UPDATE profiles
    SET points = points + 2,
        updated_at = NOW()
    WHERE id = voucher_owner_id;
  END IF;
  
  -- Increment use count on voucher
  UPDATE vouchers
  SET use_count = use_count + 1,
      updated_at = NOW()
  WHERE id = NEW.voucher_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_voucher_use_insert
AFTER INSERT ON voucher_uses
FOR EACH ROW
EXECUTE FUNCTION handle_voucher_usage();

-- 5. Cron function to deactivate reported vouchers
CREATE OR REPLACE FUNCTION deactivate_reported_vouchers()
RETURNS void AS $$
BEGIN
  UPDATE vouchers
  SET is_active = false,
      updated_at = NOW()
  WHERE report_count >= 3 AND is_active = true;
END;
$$ LANGUAGE plpgsql;

-- 6. Manual soft delete function
CREATE OR REPLACE FUNCTION soft_delete_voucher(voucher_id_param UUID, user_id_param UUID)
RETURNS void AS $$
BEGIN
  UPDATE vouchers
  SET deleted_at = NOW(),
      updated_at = NOW()
  WHERE id = voucher_id_param
    AND user_id = user_id_param
    AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- CRON JOB SETUP
-- ============================================================================

-- Schedule cron job to run every 6 hours
-- Run this separately in Supabase Dashboard under Database > Cron Jobs
-- OR if pg_cron extension is enabled:

-- SELECT cron.schedule(
--   'deactivate-reported-vouchers',
--   '0 */6 * * *',
--   $$
--   SELECT deactivate_reported_vouchers();
--   $$
-- );
