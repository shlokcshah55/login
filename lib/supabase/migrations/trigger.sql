CREATE OR REPLACE FUNCTION notify_tiktok_save()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_location_name TEXT;
    v_location_id TEXT;
    v_fcm_token TEXT;
    v_api_url TEXT := 'https://europe-west1-pinit-494520.cloudfunctions.net/send-push-notifications';
    v_api_key TEXT := 'RnP9BGrHqnMLpWcvwFFnxDmTf+ES21Yd15pIFz5CjGg='; -- Replace with the key used in your Cloud Function
BEGIN
    RAISE LOG 'notify_tiktok_save triggered for user % on location %', NEW.user_id, NEW.location_id;

    -- Only process TikTok saves
    IF NEW.action::TEXT = 'save' AND NEW.saved_method::TEXT = 'tiktok' THEN
        
        -- 1. Get Location Details
        SELECT name, location_id::TEXT
        INTO v_location_name, v_location_id
        FROM locations
        WHERE location_id = NEW.location_id;

        -- 2. Get User's FCM Token
        SELECT fcm_token INTO v_fcm_token
        FROM users
        WHERE supabase_id = NEW.user_id;

        -- Check if we have what we need
        IF v_fcm_token IS NULL OR v_fcm_token = '' THEN
            RAISE WARNING 'No FCM token found for user %', NEW.user_id;
            RETURN NEW;
        END IF;

        -- 3. Call the Cloud Function via pg_net
        -- We send the data in the format the Python function now expects
        PERFORM net.http_post(
            url := v_api_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_api_key
            ),
            body := jsonb_build_object(
                'fcm_token', v_fcm_token,
                'user_id', NEW.user_id,
                'type', 'video_processed',
                'title', 'TikTok Saved!',
                'body', 'We found ' || v_location_name || ' from your TikTok.',
                'metadata', jsonb_build_object(
                    'locationId', v_location_id,
                    'locationName', v_location_name,
                    'deepLink', 'pinit://location/' || v_location_id
                )
            )
        );

        RAISE LOG 'Request sent to Cloud Function for user %', NEW.user_id;

    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to trigger TikTok notification: %', SQLERRM;
        RETURN NEW;
END;
$$;
