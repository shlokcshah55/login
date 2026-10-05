-- Onboarding funnel analytics.
--
-- track_app_event silently drops any event name not on its allowlist and
-- discards properties not whitelisted per event. Add the five onboarding
-- events (viewed / completed / skipped per step, first save, finished) and
-- whitelist their non-PII properties: step, method, flow, elapsed_ms.
--
-- Function body change only. No table/column changes, no new grants and no
-- RLS impact: the function stays SECURITY DEFINER and keeps its existing
-- EXECUTE grants (anon, authenticated, service_role).

CREATE OR REPLACE FUNCTION "public"."track_app_event"("p_event_name" "text", "p_event_category" "text", "p_session_id" "text", "p_anon_id" "uuid", "p_screen_name" "text", "p_feature_name" "text", "p_duration_ms" integer, "p_occurred_at" timestamp with time zone, "p_app_version" "text", "p_build_number" "text", "p_platform" "text", "p_os_version" "text", "p_locale" "text", "p_timezone" "text", "p_properties" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
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
        'no_recommendations_in_area_shown',
        'onboarding_step_viewed',
        'onboarding_step_completed',
        'onboarding_step_skipped',
        'onboarding_first_save',
        'onboarding_finished'
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

    IF v_event_name LIKE 'onboarding\_%' THEN
        IF p_properties IS NOT NULL THEN
            v_properties := jsonb_strip_nulls(
                jsonb_build_object(
                    'step', LEFT(p_properties->>'step', 40),
                    'method', LEFT(p_properties->>'method', 40),
                    'flow', LEFT(p_properties->>'flow', 40),
                    'elapsed_ms', CASE
                        WHEN jsonb_typeof(p_properties->'elapsed_ms') = 'number'
                        THEN p_properties->'elapsed_ms'
                        ELSE NULL
                    END
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
$_$;
