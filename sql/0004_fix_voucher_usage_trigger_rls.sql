-- ============================================================================
-- FIX VOUCHER USAGE SIDE EFFECTS UNDER RLS
-- ============================================================================

-- The trigger updates vouchers/profiles rows that may not belong to the user
-- inserting into voucher_uses. Under RLS this can no-op unless the trigger
-- function runs with definer privileges.
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;
