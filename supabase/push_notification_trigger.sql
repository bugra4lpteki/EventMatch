-- ==============================================================================
-- EventMatch: Arka Plan & Kapalıyken Mesaj Bildirimleri SQL Yapılandırması
-- ==============================================================================

-- 1. Push Token ve FCM Token sütunlarını users tablosuna ekle
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. Async HTTP istekleri için pg_net eklentisini aktif et
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- 3. Yeni mesaj geldiğinde bildirim verisini hazırlayan fonksiyon
CREATE OR REPLACE FUNCTION public.handle_new_message_push()
RETURNS TRIGGER AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  -- Gönderen kullanıcının adını users tablosundan al
  SELECT COALESCE(name, 'Yeni Mesaj') INTO v_sender_name
  FROM public.users
  WHERE id::text = NEW.sender_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Bildirim hatası olsa bile mesajın kaydedilmesini asla engelleme
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. messages tablosuna her yeni mesaj eklendiğinde tetiklenen Trigger
DROP TRIGGER IF EXISTS tr_new_message_push ON public.messages;
CREATE TRIGGER tr_new_message_push
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_message_push();

-- 5. Realtime yayınını güvenli şekilde kontrol et (Hata vermez)
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
