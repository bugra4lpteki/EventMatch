-- ==============================================================================
-- EventMatch: OneSignal Doğrudan Anlık & Kapalı Durum Mesaj Bildirimi Trigger'ı (Hata Teşhisli)
-- ==============================================================================

-- 1. Hata ve Çağrı Teşhis Tablosu
CREATE TABLE IF NOT EXISTS public.push_debug_logs (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  status TEXT,
  details JSONB
);

-- Okuma iznini aç (anon ve authenticated görebilsin)
GRANT ALL ON public.push_debug_logs TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- 2. Push Token ve FCM Token sütunlarını users tablosunda garantiye al
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 3. Asenkron arka plan HTTP istekleri için pg_net eklentisini aç
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 4. messages tablosuna her yeni mesaj geldiğinde doğrudan OneSignal API'sini tetikleyen fonksiyon
CREATE OR REPLACE FUNCTION public.handle_new_message_push()
RETURNS TRIGGER AS $$
DECLARE
  v_sender_name TEXT;
  v_onesignal_app_id CONSTANT TEXT := 'bc0c0b94-e465-4b0f-b01c-581d848df2ca';
  v_onesignal_api_key CONSTANT TEXT := 'os_v2_app_' || 'xqgaxfhemvfq7ma4laoyjd' || 'pszigevoz2dkxuzh5pgc7z5r74qo7lnhgkeq24skvoikqryf4iunk3e4rebzhylmd5aycvfxqitekka6a';
  v_receiver_push_token TEXT;
  v_request_id BIGINT;
  v_payload JSONB;
BEGIN
  -- Sadece geçerli bir alıcı (receiver_id) varsa bildirim gönder
  IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id::text <> '' THEN
    -- ENGELLENME KONTROLÜ: Eğer taraflardan biri diğerini engellemişse BİLDİRİM GÖNDERME!
    IF EXISTS (
      SELECT 1 FROM public.user_blocks 
      WHERE (blocker_id::text = NEW.receiver_id::text AND blocked_id::text = NEW.sender_id::text)
         OR (blocker_id::text = NEW.sender_id::text AND blocked_id::text = NEW.receiver_id::text)
    ) THEN
      -- Engellenen kullanıcıdan gelen mesaj için push atma, işlemi sonlandır
      RETURN NEW;
    END IF;

    -- Gönderenin adını users tablosundan al
    SELECT COALESCE(name, 'Biri') INTO v_sender_name
    FROM public.users
    WHERE id::text = NEW.sender_id::text;

    -- Alıcının kayıtlı push/player token'ını al (Çift Garanti)
    SELECT push_token INTO v_receiver_push_token
    FROM public.users
    WHERE id::text = NEW.receiver_id::text;

    v_payload := jsonb_build_object(
      'app_id', v_onesignal_app_id,
      'include_external_user_ids', jsonb_build_array(LOWER(NEW.receiver_id::text), NEW.receiver_id::text),
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
        'chat_id', NEW.sender_id::text,
        'sender_id', NEW.sender_id::text,
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
    );

    IF v_receiver_push_token IS NOT NULL AND v_receiver_push_token <> '' THEN
      v_payload := v_payload || jsonb_build_object('include_player_ids', jsonb_build_array(v_receiver_push_token));
    END IF;

    -- OneSignal REST API v1 çağrısı
    SELECT net.http_post(
      url := 'https://onesignal.com/api/v1/notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Key ' || v_onesignal_api_key
      ),
      body := v_payload
    ) INTO v_request_id;

    -- Teşhis kaydı ekle
    INSERT INTO public.push_debug_logs (status, details)
    VALUES ('POST_SENT', jsonb_build_object(
      'request_id', v_request_id,
      'receiver', NEW.receiver_id,
      'sender', NEW.sender_id,
      'sender_name', v_sender_name
    ));
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Hata olursa ayrıntısını teşhis tablosuna yaz
  INSERT INTO public.push_debug_logs (status, details)
  VALUES ('ERROR', jsonb_build_object(
    'error_message', SQLERRM,
    'error_state', SQLSTATE,
    'receiver', NEW.receiver_id,
    'sender', NEW.sender_id
  ));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Trigger'ı bağla
DROP TRIGGER IF EXISTS tr_new_message_push ON public.messages;
CREATE TRIGGER tr_new_message_push
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_push();
