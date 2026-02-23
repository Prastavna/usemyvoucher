-- ============================================================================
-- PUBLIC VOUCHER BROWSING
-- ============================================================================

-- Allow both anonymous and authenticated users to browse active, non-deleted vouchers.
DROP POLICY IF EXISTS "Authenticated users can view active non-deleted vouchers" ON vouchers;

CREATE POLICY "Public can view active non-deleted vouchers"
  ON vouchers FOR SELECT
  TO public
  USING (is_active = true AND deleted_at IS NULL);
