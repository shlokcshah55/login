-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.bubble_locations (
  bubble_location_id uuid NOT NULL DEFAULT gen_random_uuid(),
  bubble_id uuid NOT NULL,
  location_id bigint NOT NULL,
  added_by uuid,
  added_at timestamp without time zone NOT NULL DEFAULT now(),
  note text,
  CONSTRAINT bubble_locations_pkey PRIMARY KEY (bubble_location_id),
  CONSTRAINT bubble_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id),
  CONSTRAINT bubble_locations_bubble_id_fkey FOREIGN KEY (bubble_id) REFERENCES public.bubbles(bubble_id),
  CONSTRAINT bubble_locations_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.bubble_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bubble_id uuid NOT NULL,
  user_id uuid NOT NULL,
  added_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT bubble_members_pkey PRIMARY KEY (id),
  CONSTRAINT bubble_members_bubble_id_fkey FOREIGN KEY (bubble_id) REFERENCES public.bubbles(bubble_id),
  CONSTRAINT bubble_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.bubbles (
  bubble_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  is_private boolean NOT NULL DEFAULT false,
  activity smallint,
  CONSTRAINT bubbles_pkey PRIMARY KEY (bubble_id),
  CONSTRAINT bubbles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.location_popularity_app (
  location_id bigint NOT NULL,
  saves_count integer NOT NULL DEFAULT 0,
  dislikes_count integer NOT NULL DEFAULT 0,
  updated_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT location_popularity_app_pkey PRIMARY KEY (location_id),
  CONSTRAINT location_popularity_app_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id)
);
CREATE TABLE public.location_reviews (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  content text,
  rating integer,
  user_id uuid,
  private boolean DEFAULT false,
  location_id bigint,
  CONSTRAINT location_reviews_pkey PRIMARY KEY (id),
  CONSTRAINT location_reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id),
  CONSTRAINT location_reviews_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id)
);
CREATE TABLE public.location_tags (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  location_id bigint,
  tag_id uuid,
  score numeric,
  source text,
  metadata jsonb,
  CONSTRAINT location_tags_pkey PRIMARY KEY (id),
  CONSTRAINT location_tags_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id),
  CONSTRAINT location_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(tag_id)
);
CREATE TABLE public.locations (
  location_id bigint NOT NULL DEFAULT nextval('locations_location_id_seq'::regclass),
  name text NOT NULL,
  vicinity text,
  lat numeric,
  lng numeric,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  cuisine text,
  rating real,
  user_ratings_total numeric,
  price_level numeric,
  photo_reference text,
  saved_count smallint,
  google_place_id text,
  business_status text,
  editorial_summary text,
  website text,
  international_phone_number text,
  types text,
  opening_hours_text ARRAY,
  opening_hours_periods jsonb,
  open_now boolean,
  cuisine_detected text,
  cuisine_source text,
  cuisine_primary text,
  top_review_language text,
  top_language_share numeric,
  review_language_counts_json jsonb,
  is_open_late boolean,
  is_open_early boolean,
  is_sunday_open boolean,
  price_bucket text,
  log_reviews numeric,
  derived_attributes jsonb,
  data_version text NOT NULL DEFAULT 'v1'::text,
  ingested_at timestamp with time zone NOT NULL DEFAULT now(),
  photo_reference_valid_until timestamp with time zone,
  photo_reference_score text,
  image_stored boolean DEFAULT false,
  emoji text,
  CONSTRAINT locations_pkey PRIMARY KEY (location_id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bubble_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text,
  message_type text DEFAULT 'text'::text,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  is_deleted boolean DEFAULT false,
  replied_to_message_id uuid,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_bubble_id_fkey FOREIGN KEY (bubble_id) REFERENCES public.bubbles(bubble_id),
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(supabase_id),
  CONSTRAINT messages_replied_to_message_id_fkey FOREIGN KEY (replied_to_message_id) REFERENCES public.messages(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  title text,
  message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.recommendation_candidates (
  candidate_id uuid NOT NULL DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL,
  location_id bigint NOT NULL,
  rank integer,
  score real NOT NULL,
  reason jsonb,
  features jsonb,
  generated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT recommendation_candidates_pkey PRIMARY KEY (candidate_id),
  CONSTRAINT recommendation_candidates_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.recommendation_runs(run_id),
  CONSTRAINT recommendation_candidates_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id)
);
CREATE TABLE public.recommendation_runs (
  run_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  run_type text NOT NULL CHECK (run_type = ANY (ARRAY['user_feed'::text, 'bubble_feed'::text, 'adhoc'::text, 'batch_explore'::text])),
  params jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'running'::text, 'succeeded'::text, 'failed'::text])),
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  finished_at timestamp with time zone,
  notes text,
  CONSTRAINT recommendation_runs_pkey PRIMARY KEY (run_id),
  CONSTRAINT recommendation_runs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.tags (
  tag_id uuid NOT NULL DEFAULT gen_random_uuid(),
  text text,
  prompt_description text,
  tag_type text,
  Colour text,
  CONSTRAINT tags_pkey PRIMARY KEY (tag_id)
);
CREATE TABLE public.user_chat_state (
  user_id uuid NOT NULL,
  bubble_id uuid NOT NULL,
  last_read_at timestamp with time zone DEFAULT now(),
  muted boolean DEFAULT false,
  CONSTRAINT user_chat_state_pkey PRIMARY KEY (user_id, bubble_id),
  CONSTRAINT user_chat_state_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id),
  CONSTRAINT user_chat_state_bubble_id_fkey FOREIGN KEY (bubble_id) REFERENCES public.bubbles(bubble_id)
);
CREATE TABLE public.user_friends (
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  followee_id uuid NOT NULL,
  follower_id uuid NOT NULL,
  status USER-DEFINED,
  influence smallint,
  CONSTRAINT user_friends_pkey PRIMARY KEY (followee_id, follower_id),
  CONSTRAINT user_friends_followee_id_fkey FOREIGN KEY (followee_id) REFERENCES public.users(supabase_id),
  CONSTRAINT user_friends_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.user_location_actions (
  action_id bigint NOT NULL DEFAULT nextval('user_location_actions_action_id_seq'::regclass),
  location_id bigint NOT NULL,
  action USER-DEFINED NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  saved_method USER-DEFINED,
  preference USER-DEFINED,
  user_id uuid,
  source_video_url text,
  acked boolean,
  CONSTRAINT user_location_actions_pkey PRIMARY KEY (action_id),
  CONSTRAINT user_location_actions_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id),
  CONSTRAINT user_location_actions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id)
);
CREATE TABLE public.user_recommendations (
  user_id uuid NOT NULL,
  location_id bigint NOT NULL,
  score real NOT NULL,
  generated_at timestamp without time zone DEFAULT now(),
  reason jsonb,
  CONSTRAINT user_recommendations_pkey PRIMARY KEY (user_id, location_id),
  CONSTRAINT user_recommendations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id),
  CONSTRAINT user_recommendations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id)
);
CREATE TABLE public.user_tag_affinities (
  user_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  affinity real NOT NULL CHECK (affinity >= 0::double precision AND affinity <= 100::double precision),
  evidence jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_tag_affinities_pkey PRIMARY KEY (user_id, tag_id),
  CONSTRAINT user_tag_affinities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(supabase_id),
  CONSTRAINT user_tag_affinities_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(tag_id)
);
CREATE TABLE public.users (
  name text NOT NULL DEFAULT ''::text,
  email text NOT NULL DEFAULT ''::text UNIQUE,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  supabase_id uuid NOT NULL,
  bio text DEFAULT ''::text,
  profile_image_url text,
  phone_number text,
  spice_tolerance smallint,
  wizard_completed boolean,
  username text NOT NULL,
  fcm_token text,
  fcm_token_updated_at timestamp with time zone,
  CONSTRAINT users_pkey PRIMARY KEY (supabase_id)
);
CREATE TABLE public.v_action_exists (
  exists boolean
);
CREATE TABLE public.waitlist (
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  email text NOT NULL,
  CONSTRAINT waitlist_pkey PRIMARY KEY (email)
);