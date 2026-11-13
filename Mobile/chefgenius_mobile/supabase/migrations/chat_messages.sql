-- =====================================================
-- CHAT MESSAGES TABLE FOR CHEFGENIUS
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_user BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create index for fast queries
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);

-- 3. Enable Row Level Security
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies - Users can only access their own messages
CREATE POLICY "Users can read own messages" ON chat_messages
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own messages" ON chat_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own messages" ON chat_messages
  FOR DELETE USING (auth.uid() = user_id);

-- 5. Function to auto-delete messages older than 7 days
CREATE OR REPLACE FUNCTION delete_old_chat_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM chat_messages 
  WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Schedule auto-delete (run daily via pg_cron if available)
-- Note: If pg_cron is not enabled, you can call this function manually or via Edge Function
-- SELECT cron.schedule('delete-old-chats', '0 3 * * *', 'SELECT delete_old_chat_messages()');

-- =====================================================
-- DONE! Copy and paste this entire script into
-- Supabase Dashboard > SQL Editor > New Query > Run
-- =====================================================
