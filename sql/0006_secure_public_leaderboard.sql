-- ============================================================================
-- SECURE PUBLIC LEADERBOARD
-- ============================================================================

-- Revert broad public profile reads introduced for public leaderboard.
DROP POLICY IF EXISTS "Public can view profiles" ON profiles;

CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

-- Expose leaderboard through a controlled, public-safe RPC.
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
    p.avatar_url,
    COALESCE(p.points, 0) AS points
  FROM public.profiles p
  ORDER BY p.points DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(limit_count, 100));
$$;

REVOKE ALL ON FUNCTION public.get_public_leaderboard(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_leaderboard(INTEGER) TO anon, authenticated;
