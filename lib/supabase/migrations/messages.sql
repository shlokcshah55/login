-- Messages directly linked to bubbles
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bubble_id UUID NOT NULL REFERENCES bubbles(bubble_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(supabase_id),
    content TEXT,
    message_type TEXT DEFAULT 'text', -- text, image, location, restaurant_share
    metadata JSONB, -- for images, locations, restaurant details, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT false,
    replied_to_message_id UUID REFERENCES messages(id)
);

-- Track each user's read status per bubble chat
CREATE TABLE user_chat_state (
    user_id UUID REFERENCES users(supabase_id) ON DELETE CASCADE,
    bubble_id UUID REFERENCES bubbles(bubble_id) ON DELETE CASCADE,
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    muted BOOLEAN DEFAULT false,
    PRIMARY KEY (user_id, bubble_id)  -- Fixed: was conversation_id
);


-- Speed up message queries by bubble (most recent first)
CREATE INDEX idx_messages_bubble_created 
    ON messages(bubble_id, created_at DESC);

-- Speed up user state lookups
CREATE INDEX idx_user_chat_state_user 
    ON user_chat_state(user_id);

CREATE INDEX idx_user_chat_state_bubble 
    ON user_chat_state(bubble_id);

-- Speed up finding unread messages
CREATE INDEX idx_messages_created 
    ON messages(created_at);

-- Speed up sender lookups
CREATE INDEX idx_messages_sender 
    ON messages(sender_id);

-- Speed up reply lookups
CREATE INDEX idx_messages_replied_to 
    ON messages(replied_to_message_id) 
    WHERE replied_to_message_id IS NOT NULL;



-- View for user's bubble chats with unread counts
CREATE OR REPLACE VIEW user_bubble_chats AS
SELECT 
    b.bubble_id,
    b.name as bubble_name,
    ucs.user_id,
    ucs.last_read_at,
    ucs.muted,
    COALESCE(
        (SELECT COUNT(*) 
         FROM messages m 
         WHERE m.bubble_id = b.bubble_id 
         AND m.created_at > ucs.last_read_at 
         AND m.is_deleted = false
         AND m.sender_id != ucs.user_id), 
        0
    ) as unread_count,
    (SELECT json_build_object(
        'id', m.id,
        'content', m.content,
        'sender_id', m.sender_id,
        'message_type', m.message_type,
        'created_at', m.created_at
     )
     FROM messages m
     WHERE m.bubble_id = b.bubble_id 
     AND m.is_deleted = false
     ORDER BY m.created_at DESC 
     LIMIT 1
    ) as last_message,
    (SELECT MAX(created_at)
     FROM messages m
     WHERE m.bubble_id = b.bubble_id
     AND m.is_deleted = false
    ) as last_message_at
FROM bubbles b
INNER JOIN user_chat_state ucs ON b.bubble_id = ucs.bubble_id;



CREATE OR REPLACE FUNCTION initialize_bubble_chat(
    p_bubble_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Create chat state if doesn't exist
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) DO NOTHING;
END;
$$;


-- Send a message
CREATE OR REPLACE FUNCTION send_message(
    p_bubble_id UUID,
    p_content TEXT,
    p_message_type TEXT DEFAULT 'text',
    p_metadata JSONB DEFAULT NULL,
    p_replied_to UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_message_id UUID;
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Insert message
    INSERT INTO messages (
        bubble_id, 
        sender_id, 
        content, 
        message_type, 
        metadata,
        replied_to_message_id
    )
    VALUES (
        p_bubble_id, 
        auth.uid(), 
        p_content, 
        p_message_type, 
        p_metadata,
        p_replied_to
    )
    RETURNING id INTO v_message_id;
    
    -- Update sender's last_read_at (they've seen their own message)
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) 
    DO UPDATE SET last_read_at = NOW();
    
    RETURN v_message_id;
END;
$$;



-- Mark bubble chat as read for current user
CREATE OR REPLACE FUNCTION mark_bubble_read(
    p_bubble_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Update last_read_at
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (auth.uid(), p_bubble_id, NOW())
    ON CONFLICT (user_id, bubble_id) 
    DO UPDATE SET last_read_at = NOW();
END;
$$;


-- Get messages with pagination
CREATE OR REPLACE FUNCTION get_bubble_messages(
    p_bubble_id UUID,
    p_limit INT DEFAULT 50,
    p_before_timestamp TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    sender_id UUID,
    sender_name TEXT,
    sender_avatar_url TEXT,
    content TEXT,
    message_type TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    replied_to_message_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify user is a bubble member
    IF NOT EXISTS (
        SELECT 1 FROM bubble_members
        WHERE bubble_id = p_bubble_id 
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this bubble';
    END IF;
    
    -- Return messages
    RETURN QUERY
    SELECT 
        m.id,
        m.sender_id,
        u.name as sender_name,
        u.avatar_url as sender_avatar_url,
        m.content,
        m.message_type,
        m.metadata,
        m.created_at,
        m.updated_at,
        m.replied_to_message_id
    FROM messages m
    JOIN users u ON m.sender_id = u.supabase_id
    WHERE m.bubble_id = p_bubble_id 
    AND m.is_deleted = false
    AND (p_before_timestamp IS NULL OR m.created_at < p_before_timestamp)
    ORDER BY m.created_at DESC
    LIMIT p_limit;
END;
$$;


-- Get user's bubble chats (with unread counts)
CREATE OR REPLACE FUNCTION get_user_chats()
RETURNS TABLE (
    bubble_id UUID,
    bubble_name TEXT,
    last_message_at TIMESTAMPTZ,
    unread_count BIGINT,
    last_message JSONB,
    muted BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ubc.bubble_id,
        ubc.bubble_name,
        ubc.last_message_at,
        ubc.unread_count,
        ubc.last_message,
        ubc.muted
    FROM user_bubble_chats ubc
    WHERE ubc.user_id = auth.uid()
    ORDER BY ubc.last_message_at DESC NULLS LAST;
END;
$$;



-- =====================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE user_chat_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- User chat state: users can only see their own state
CREATE POLICY "Users can view their own chat state"
    ON user_chat_state FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "System can manage chat state"
    ON user_chat_state FOR ALL
    USING (false); -- Only via RPC

-- Messages: users can see messages in their bubbles
CREATE POLICY "Users can view messages in their bubbles"
    ON messages FOR SELECT
    USING (
        bubble_id IN (
            SELECT bubble_id 
            FROM bubble_members 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "System can create messages"
    ON messages FOR INSERT
    WITH CHECK (false); -- Only via RPC

CREATE POLICY "System can update messages"
    ON messages FOR UPDATE
    USING (false); -- Only via RPC

-- =====================================================
-- 6. TRIGGERS & FUNCTIONS
-- =====================================================

-- Trigger to auto-initialize chat state for new bubble members
CREATE OR REPLACE FUNCTION initialize_chat_state_for_new_member()
RETURNS TRIGGER AS $$
BEGIN
    -- Initialize chat state for new member
    INSERT INTO user_chat_state (user_id, bubble_id, last_read_at)
    VALUES (NEW.user_id, NEW.bubble_id, NOW())
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_bubble_member_added
    AFTER INSERT ON bubble_members
    FOR EACH ROW
    EXECUTE FUNCTION initialize_chat_state_for_new_member();

-- Trigger for real-time message notifications
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify via pg_notify for real-time subscriptions
    PERFORM pg_notify(
        'new_message',
        json_build_object(
            'bubble_id', NEW.bubble_id,
            'message_id', NEW.id,
            'sender_id', NEW.sender_id,
            'message_type', NEW.message_type,
            'content', NEW.content
        )::text
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_message_created
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();
