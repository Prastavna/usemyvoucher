-- Migration: Deactivate expired vouchers cron job
-- Description: Creates a function to deactivate vouchers past their expiry_date and schedules it to run at midnight

-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Function to deactivate expired vouchers
CREATE OR REPLACE FUNCTION public.deactivate_expired_vouchers()
RETURNS TABLE(deactivated_count bigint) 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  affected_rows bigint;
BEGIN
  -- Update vouchers where expiry_date is in the past and is_active is still true
  UPDATE public.vouchers
  SET 
    is_active = FALSE,
    updated_at = NOW()
  WHERE 
    expiry_date < CURRENT_DATE
    AND is_active = TRUE
    AND deleted_at IS NULL;
  
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  
  -- Return the count of deactivated vouchers
  RETURN QUERY SELECT affected_rows;
END;
$$;

-- Grant execute permission to authenticated users (for manual testing if needed)
GRANT EXECUTE ON FUNCTION public.deactivate_expired_vouchers() TO authenticated;

-- Schedule the cron job to run at midnight UTC every day
SELECT cron.schedule(
  'deactivate-expired-vouchers',
  '0 0 * * *',  -- At 00:00 (midnight) every day
  $$
  SELECT public.deactivate_expired_vouchers();
  $$
);

-- Optional: Add a comment for documentation
COMMENT ON FUNCTION public.deactivate_expired_vouchers() IS 
  'Deactivates vouchers that have passed their expiry_date. Scheduled to run daily at midnight via pg_cron.';
