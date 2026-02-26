-- ============================================================================
-- PROFILE PREFERENCES
-- ============================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS show_profile_picture BOOLEAN NOT NULL DEFAULT true;
