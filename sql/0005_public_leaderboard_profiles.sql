-- ============================================================================
-- PUBLIC LEADERBOARD PROFILES
-- ============================================================================

-- Leaderboard is public, so profile reads used by leaderboard must be public too.
-- Keep this broad policy only if you are okay with public profile visibility.
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;

CREATE POLICY "Public can view profiles"
  ON profiles FOR SELECT
  TO public
  USING (true);
