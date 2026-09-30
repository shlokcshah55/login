-- Drop the trigger first, then the function
DROP TRIGGER IF EXISTS trigger_notify_tiktok_save ON user_location_actions;

DROP FUNCTION IF EXISTS notify_tiktok_save();
