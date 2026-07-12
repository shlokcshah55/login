ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS dismissed_at timestamptz;

CREATE INDEX IF NOT EXISTS notifications_user_visible_recent_idx
    ON public.notifications (user_id, created_at DESC)
    WHERE dismissed_at IS NULL;
