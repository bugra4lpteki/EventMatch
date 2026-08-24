-- ==============================================================================
-- EventMatch: Push Notification Database Webhook & Triggers
-- ==============================================================================
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/_/sql

-- 1. Ensure 'push_token' and 'fcm_token' columns exist in public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Enable pg_net extension (for making async HTTP requests from triggers)
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 3. Push Notification Dispatcher Function
CREATE OR REPLACE FUNCTION public.handle_new_message_push()
RETURNS TRIGGER AS $$
DECLARE
  v_sender_name TEXT;
  v_receiver_token TEXT;
  v_payload JSONB;
BEGIN
  -- Get sender name
  SELECT COALESCE(name, 'Yeni Mesaj') INTO v_sender_name
  FROM public.users
  WHERE id::text = NEW.sender_id;

  -- Create payload
  v_payload := jsonb_build_object(
    'record', jsonb_build_object(
      'id', NEW.id,
      'sender_id', NEW.sender_id,
      'sender_name', COALESCE(v_sender_name, 'Biri'),
      'receiver_id', NEW.receiver_id,
      'content', NEW.content,
      'match_id', NEW.match_id,
      'created_at', NEW.created_at
    )
  );

  -- Note: You can also configure Supabase Webhooks directly from Dashboard -> Database -> Webhooks
  -- Target URL: https://<YOUR-PROJECT-REF>.supabase.co/functions/v1/push-notification
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never fail message insert if push notification encounters an error
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger on new message insertion
DROP TRIGGER IF EXISTS tr_new_message_push ON public.messages;
CREATE TRIGGER tr_new_message_push
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_push();
