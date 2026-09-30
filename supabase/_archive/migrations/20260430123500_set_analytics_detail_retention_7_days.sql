-- ============================================================================
-- Reduce analytics raw-detail retention to 7 days
-- ============================================================================
-- This keeps only the most recent 7 days of raw events in
-- public.app_analytics_events.

-- 1) Update cleanup function default to 7 days
CREATE OR REPLACE FUNCTION public.cleanup_old_app_analytics_events(
    p_retention INTERVAL DEFAULT INTERVAL '7 days'
) RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM public.app_analytics_events
    WHERE occurred_at < NOW() - p_retention;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.cleanup_old_app_analytics_events(INTERVAL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_old_app_analytics_events(INTERVAL) TO service_role;

-- 2) Apply cleanup immediately so storage drops right away
SELECT public.cleanup_old_app_analytics_events(INTERVAL '7 days');

-- 3) Keep the daily cron job but with 7-day retention
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        IF EXISTS (
            SELECT 1
            FROM cron.job
            WHERE jobname = 'cleanup_old_app_analytics_events_daily'
        ) THEN
            PERFORM cron.unschedule('cleanup_old_app_analytics_events_daily');
        END IF;

        PERFORM cron.schedule(
            'cleanup_old_app_analytics_events_daily',
            '15 3 * * *',
            $job$SELECT public.cleanup_old_app_analytics_events(INTERVAL '7 days');$job$
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron scheduling skipped: %', SQLERRM;
END;
$$;
