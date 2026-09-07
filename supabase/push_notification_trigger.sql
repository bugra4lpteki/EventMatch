-- ==============================================================================
-- EventMatch: Arka Plan & Kapalıyken Mesaj Bildirimleri SQL Yapılandırması
-- ==============================================================================

-- 1. Push Token ve FCM Token sütunlarını users tablosuna ekle
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Asenkron HTTP istekleri için pg_net eklentisini aktif et
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 3. Yeni mesaj eklendiğinde Edge Function'a bildirim isteği atan tetikleyici fonksiyon
CREATE OR REPLACE FUNCTION public.handle_new_message_push()
RETURNS TRIGGER AS $$
DECLARE
  v_supabase_url TEXT := 'https://pqtpogebnfubrqowlnkq.supabase.co';
  v_anon_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxdHBvZ2VibmZ1YnJxb3dsbmtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwNjM4NjMsImV4cCI6MjEwMDYzOTg2M30.jHzTJadRqvmrlGGjkFZ9qNUKNi_2CatfBGUxCZ_cn6o';
  v_request_id BIGINT;
BEGIN
  -- Sadece geçerli bir alıcı (receiver_id) varsa push gönder
  IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id <> '' THEN
    -- Edge function çağrısı (pg_net ile asenkron arka plan HTTP isteği)
    SELECT net.http_post(
      url := v_supabase_url || '/functions/v1/push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_anon_key
      ),
      body := jsonb_build_object(
        'record', jsonb_build_object(
          'id', NEW.id,
          'sender_id', NEW.sender_id,
          'receiver_id', NEW.receiver_id,
          'content', NEW.content,
          'match_id', NEW.match_id,
          'created_at', NEW.created_at
        )
      )
    ) INTO v_request_id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Bildirimde herhangi bir ağ/bağlantı hatası olsa dahi mesajın DB'ye yazılmasını ASLA engelleme
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. messages tablosuna her yeni mesaj eklendiğinde tetiklenen Trigger
DROP TRIGGER IF EXISTS tr_new_message_push ON public.messages;
CREATE TRIGGER tr_new_message_push
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_push();

-- 5. Realtime yayınını tüm mesaj ve eşleşmeler için garantiye al
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
