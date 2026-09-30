-- Track "no recommendations in area" events and (optionally) alert internal recipients.

-- -----------------------------------------------------------------------------
-- 1) Expand the analytics whitelist to accept the new event and persist metadata
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.track_app_event(
    p_event_name TEXT,
    p_event_category TEXT,
    p_session_id TEXT,
    p_anon_id UUID,
    p_screen_name TEXT,
    p_feature_name TEXT,
    p_duration_ms INT,
    p_occurred_at TIMESTAMPTZ,
    p_app_version TEXT,
    p_build_number TEXT,
    p_platform TEXT,
    p_os_version TEXT,
    p_locale TEXT,
    p_timezone TEXT,
    p_properties JSONB DEFAULT '{}'::JSONB
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_event_name TEXT := LOWER(TRIM(COALESCE(p_event_name, '')));
    v_session_id TEXT := TRIM(COALESCE(p_session_id, ''));
    v_feature_name TEXT := NULLIF(TRIM(COALESCE(p_feature_name, '')), '');
    v_properties JSONB := NULL;
BEGIN
    IF v_event_name = '' THEN
        RETURN;
    END IF;

    IF v_event_name !~ '^[a-z][a-z0-9_]*$' THEN
        RETURN;
    END IF;

    IF v_session_id = '' THEN
        RETURN;
    END IF;

    IF v_user_id IS NULL AND p_anon_id IS NULL THEN
        RETURN;
    END IF;

    IF v_event_name NOT IN (
        'session_started',
        'app_foregrounded',
        'session_ended',
        'screen_view',
        'tab_switched',
        'search_opened',
        'magic_search_submitted',
        'location_card_opened',
        'location_saved',
        'location_disliked',
        'collection_created',
        'bubble_opened',
        'notification_permission_prompted',
        'notification_permission_result',
        'notification_received',
        'notification_opened',
        'deep_link_routed',
        'deep_link_failed',
        'no_recommendations_in_area_shown'
    ) THEN
        RETURN;
    END IF;

    IF v_event_name = 'notification_permission_result' THEN
        IF p_properties IS NOT NULL
           AND COALESCE(p_properties->>'status', '') <> '' THEN
            v_properties := jsonb_build_object(
                'status',
                p_properties->>'status'
            );
        END IF;
    END IF;

    IF v_event_name = 'no_recommendations_in_area_shown' THEN
        IF p_properties IS NOT NULL THEN
            v_properties := jsonb_strip_nulls(
                jsonb_build_object(
                    'list_type', p_properties->'list_type',
                    'vibe_tag_count', p_properties->'vibe_tag_count',
                    'cuisine_tag_count', p_properties->'cuisine_tag_count',
                    'availability_filter', p_properties->'availability_filter',
                    'center_lat', p_properties->'center_lat',
                    'center_lng', p_properties->'center_lng',
                    'radius_km', p_properties->'radius_km',
                    'camera_zoom', p_properties->'camera_zoom'
                )
            );
        END IF;
    END IF;

    IF v_event_name NOT IN (
        'search_opened',
        'magic_search_submitted',
        'location_card_opened',
        'location_saved',
        'location_disliked',
        'collection_created',
        'bubble_opened'
    ) THEN
        v_feature_name := NULL;
    END IF;

    INSERT INTO public.app_analytics_events (
        occurred_at,
        event_name,
        session_id,
        user_id,
        anon_id,
        feature_name,
        properties
    )
    VALUES (
        COALESCE(p_occurred_at, NOW()),
        v_event_name,
        v_session_id,
        v_user_id,
        p_anon_id,
        v_feature_name,
        v_properties
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.track_app_event(
    TEXT, TEXT, TEXT, UUID, TEXT, TEXT, INT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.track_app_event(
    TEXT, TEXT, TEXT, UUID, TEXT, TEXT, INT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
) TO anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2) Optional internal push alerting (pg_net → send-push-notifications)
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "public";

CREATE TABLE IF NOT EXISTS public.internal_alert_config (
    id INTEGER PRIMARY KEY DEFAULT 1,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    push_api_url TEXT,
    push_api_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT internal_alert_config_singleton_chk CHECK (id = 1)
);

INSERT INTO public.internal_alert_config (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.internal_alert_recipients (
    user_id UUID PRIMARY KEY REFERENCES public.users (supabase_id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

REVOKE ALL ON TABLE public.internal_alert_config FROM anon, authenticated;
REVOKE ALL ON TABLE public.internal_alert_recipients FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internal_alert_config TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internal_alert_recipients TO service_role;

CREATE OR REPLACE FUNCTION public.notify_no_recommendations_in_area_internal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_enabled BOOLEAN;
    v_api_url TEXT;
    v_api_key TEXT;
    v_title TEXT;
    v_body TEXT;
    v_meta JSONB;
    r RECORD;
BEGIN
    IF NEW.event_name IS NULL OR NEW.event_name <> 'no_recommendations_in_area_shown' THEN
        RETURN NEW;
    END IF;

    SELECT enabled, push_api_url, push_api_key
    INTO v_enabled, v_api_url, v_api_key
    FROM public.internal_alert_config
    WHERE id = 1;

    IF COALESCE(v_enabled, FALSE) IS FALSE THEN
        RETURN NEW;
    END IF;

    IF v_api_url IS NULL OR TRIM(v_api_url) = '' OR v_api_key IS NULL OR TRIM(v_api_key) = '' THEN
        RETURN NEW;
    END IF;

    v_title := 'Out of area search';
    v_body := 'A user hit "Sorry, we haven''t landed in your area yet".';
    v_meta := COALESCE(NEW.properties, '{}'::jsonb);

    FOR r IN
        SELECT u.supabase_id AS user_id, u.fcm_token AS fcm_token
        FROM public.internal_alert_recipients recipients
        JOIN public.users u ON u.supabase_id = recipients.user_id
        WHERE recipients.enabled = TRUE
          AND u.fcm_token IS NOT NULL
          AND TRIM(u.fcm_token) <> ''
    LOOP
        PERFORM net.http_post(
            url := v_api_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_api_key
            ),
            body := jsonb_build_object(
                'fcm_token', r.fcm_token,
                'user_id', r.user_id,
                -- Reuse an existing app notification type that requires no deep-link.
                'type', 'notes_import_complete',
                'title', v_title,
                'body', v_body,
                'metadata', jsonb_build_object(
                    'sourceEvent', NEW.event_name,
                    'occurredAt', NEW.occurred_at,
                    'properties', v_meta
                )
            )
        );
    END LOOP;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Never fail app analytics ingestion because alerting is misconfigured.
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_no_recommendations_in_area_internal
    ON public.app_analytics_events;
CREATE TRIGGER trg_notify_no_recommendations_in_area_internal
AFTER INSERT ON public.app_analytics_events
FOR EACH ROW
EXECUTE FUNCTION public.notify_no_recommendations_in_area_internal();
