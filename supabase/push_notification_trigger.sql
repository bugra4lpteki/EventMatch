-- ==============================================================================
-- EventMatch: OneSignal Doğrudan Anlık & Kapalı Durum Mesaj Bildirimi Trigger'ı
-- ==============================================================================

-- 1. Push Token ve FCM Token sütunlarını users tablosunda garantiye al
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Asenkron arka plan HTTP istekleri için pg_net eklentisini aç
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 3. messages tablosuna her yeni mesaj geldiğinde doğrudan OneSignal API'sini tetikleyen fonksiyon
CREATE OR REPLACE FUNCTION public.handle_new_message_push()
RETURNS TRIGGER AS $$
DECLARE
  v_sender_name TEXT;
  v_onesignal_app_id CONSTANT TEXT := 'bc0c0b94-e465-4b0f-b01c-581d848df2ca';
  v_onesignal_api_key CONSTANT TEXT := 'YOUR_ONESIGNAL_REST_API_KEY';
  v_request_id BIGINT;
BEGIN
  -- Sadece geçerli bir alıcı (receiver_id) varsa bildirim gönder
  IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id <> '' THEN
    -- Gönderenin adını users tablosundan al
    SELECT COALESCE(name, 'Biri') INTO v_sender_name
    FROM public.users
    WHERE id::text = NEW.sender_id;

    -- OneSignal REST API v1 çağrısı (Uygulama kapalıyken bile Apple APNs & Google FCM üzerinden telefon titrer)
    SELECT net.http_post(
      url := 'https://onesignal.com/api/v1/notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Key ' || v_onesignal_api_key
      ),
      body := jsonb_build_object(
        'app_id', v_onesignal_app_id,
        'include_external_user_ids', jsonb_build_array(LOWER(NEW.receiver_id), NEW.receiver_id),
        'channel_for_external_user_ids', 'push',
        'priority', 10,
        'android_priority', 5,
        'headings', jsonb_build_object(
          'tr', '💬 ' || COALESCE(v_sender_name, 'Yeni Mesaj'),
          'en', '💬 ' || COALESCE(v_sender_name, 'New Message')
        ),
        'contents', jsonb_build_object(
          'tr', NEW.content,
          'en', NEW.content
        ),
        'data', jsonb_build_object(
          'chat_id', NEW.sender_id,
          'sender_id', NEW.sender_id,
          'sender_name', COALESCE(v_sender_name, 'Yeni Mesaj'),
          'match_id', NEW.match_id,
          'type', 'new_message'
        ),
        'ios_badgeType', 'Increase',
        'ios_badgeCount', 1,
        'ios_sound', 'default',
        'android_sound', 'default',
        'android_channel_id', 'high_importance_channel',
        'apns_priority', 10,
        'content_available', true
      )
    ) INTO v_request_id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Bildirim ağında hata olsa bile mesajın DB'ye yazılmasını ASLA engelleme
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger'ı bağla
DROP TRIGGER IF EXISTS tr_new_message_push ON public.messages;
CREATE TRIGGER tr_new_message_push
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_push();

-- 5. Realtime replication yayını
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
  
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
  EXCEPTION WHEN duplicate_object THEN
    NULL;
  END;
END $$;
