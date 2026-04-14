-- Drop the trigger first, then the function
DROP TRIGGER IF EXISTS notify_tiktok_save ON user_saved_locations;

DROP FUNCTION IF EXISTS notify_tiktok_save();
