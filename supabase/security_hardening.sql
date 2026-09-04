-- ==============================================================================
-- EventMatch Supabase Güvenlik Sertleştirme (Security Hardening) SQL Betiği
-- Kapsanan Maddeler: 3, 4, 7, 15, 18, 21
-- ==============================================================================

-- 1. ROLLER VE YETKİ MATRİSİ (RBAC - Madde 3, 4, 18)
-- users tablosuna rol alanı ekleme (user, organizer, admin)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' CHECK (role IN ('user', 'organizer', 'admin'));

-- Güvenli Rol Doğrulama Fonksiyonları (Server-Side Execution)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_organizer_or_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('organizer', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. KRİTİK AÇIKLARIN DÜZELTİLMESİ (RLS - Madde 3, 4, 18)

-- A) MESAJLAR TABLOSU: Herkesin tüm mesajları okumasını ve yazmasını engelleyen kural
-- Eski gevşek politikaları temizle:
DROP POLICY IF EXISTS "Herkes mesaj ekleyebilir" ON public.messages;
DROP POLICY IF EXISTS "Herkes mesajları görebilir" ON public.messages;
DROP POLICY IF EXISTS "Allow read own messages" ON public.messages;
DROP POLICY IF EXISTS "Allow insert own messages" ON public.messages;
DROP POLICY IF EXISTS "Sadece eslesme taraflari mesajlari gorebilir" ON public.messages;
DROP POLICY IF EXISTS "Sadece eslesme taraflari mesaj gonderebilir" ON public.messages;

-- YENİ SIKI POLİTİKALAR: Yalnızca mesajın tarafları (gönderici/alıcı) veya eşleşme tarafları mesajları görebilir
CREATE POLICY "Sadece eslesme taraflari mesajlari gorebilir" 
ON public.messages 
FOR SELECT 
USING (
  sender_id::text = auth.uid()::text 
  OR receiver_id::text = auth.uid()::text
  OR EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.id = messages.match_id
      AND (m.user_id_1::text = auth.uid()::text OR m.user_id_2::text = auth.uid()::text)
  )
);

-- Sadece gönderici kendisi olan ve alıcısı veya eşleşmesi olanlar mesaj ekleyebilir
CREATE POLICY "Sadece eslesme taraflari mesaj gonderebilir" 
ON public.messages 
FOR INSERT 
WITH CHECK (
  sender_id::text = auth.uid()::text
  AND (
    (receiver_id IS NOT NULL AND receiver_id::text != '')
    OR EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = messages.match_id
        AND (m.user_id_1::text = auth.uid()::text OR m.user_id_2::text = auth.uid()::text)
    )
  )
);

-- B) ETKİNLİKLER TABLOSU: Her authenticated kullanıcının etkinlik ekleme/düzenleme açığını kapat
DROP POLICY IF EXISTS "Allow authenticated insert events" ON public.events;
DROP POLICY IF EXISTS "Allow authenticated update events" ON public.events;
DROP POLICY IF EXISTS "Sadece yetkili roller etkinlik ekleyebilir" ON public.events;
DROP POLICY IF EXISTS "Sadece yetkili roller etkinlik duzenleyebilir" ON public.events;
DROP POLICY IF EXISTS "Sadece admin etkinlik silebilir" ON public.events;

CREATE POLICY "Sadece yetkili roller etkinlik ekleyebilir" 
ON public.events 
FOR INSERT 
WITH CHECK (public.is_organizer_or_admin());

CREATE POLICY "Sadece yetkili roller etkinlik duzenleyebilir" 
ON public.events 
FOR UPDATE 
USING (public.is_organizer_or_admin());

CREATE POLICY "Sadece admin etkinlik silebilir" 
ON public.events 
FOR DELETE 
USING (public.is_admin());


-- 3. STORAGE YÜKLEME LİMİTİ VE MIME TİPİ KONTROLÜ (Madde 7)
-- Avatars bucket boyutunu 5MB (5242880 byte) ve sadece resim MIME türlerine sınırla
UPDATE storage.buckets
SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'avatars';

-- Kullanıcının sadece kendi klasörüne/dosyasına avatar yüklemesini ve silmesini sağla
DROP POLICY IF EXISTS "Auth User Avatar Upload" ON storage.objects;
DROP POLICY IF EXISTS "Auth User Avatar Delete" ON storage.objects;
DROP POLICY IF EXISTS "Kullanici sadece kendi avatarini yukleyebilir" ON storage.objects;
DROP POLICY IF EXISTS "Kullanici sadece kendi avatarini silebilir" ON storage.objects;

CREATE POLICY "Kullanici sadece kendi avatarini yukleyebilir" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Kullanici sadece kendi avatarini silebilir" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars' 
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );


-- 4. HESABI GERÇEKTEN SİL - KVKK / GDPR UYUMLU (Madde 21)
-- Kullanıcı hesabını sildiğinde tüm ilişkili verileri ve auth kaydını silen RPC
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Oturum açmış kullanıcı bulunamadı';
  END IF;

  -- 1. Mesajları temizle (tip uyuşmazlığına karşı her iki taraf ::text olarak karşılaştırılır)
  DELETE FROM public.messages 
  WHERE sender_id::text = v_user_id::text OR receiver_id::text = v_user_id::text;

  -- 2. Eşleşmeleri temizle
  DELETE FROM public.matches 
  WHERE user_id_1::text = v_user_id::text OR user_id_2::text = v_user_id::text;

  -- 3. Etkinlik katılımlarını temizle
  DELETE FROM public.event_attendees 
  WHERE user_id = v_user_id;

  -- 4. Fotoğrafları ve sosyal bağlantıları temizle
  DELETE FROM public.user_photos WHERE user_id = v_user_id;
  DELETE FROM public.user_social_links WHERE user_id = v_user_id;

  -- 5. Profil tablosundan sil
  DELETE FROM public.users WHERE id = v_user_id;

  -- 6. Supabase auth.users tablosundan sil
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
