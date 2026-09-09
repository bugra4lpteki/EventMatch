-- ============================================================
-- Supabase Storage: chat-media bucket oluşturma
-- Bu script'i Supabase Dashboard > SQL Editor'da çalıştırın
-- ============================================================

-- 1. Public bucket oluştur (varsa hata vermez)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-media',
  'chat-media',
  true,  -- Public erişim (signed URL'ye gerek kalmaz)
  5242880,  -- 5MB max dosya boyutu
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/mp4', 'audio/mpeg', 'audio/m4a', 'audio/aac']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'audio/mp4', 'audio/mpeg', 'audio/m4a', 'audio/aac'];

-- 2. Herkesin okuyabilmesi için SELECT (download) policy
CREATE POLICY "Public read access for chat-media"
ON storage.objects FOR SELECT
USING (bucket_id = 'chat-media');

-- 3. Giriş yapmış kullanıcıların yükleyebilmesi için INSERT policy
CREATE POLICY "Authenticated users can upload to chat-media"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'chat-media'
  AND auth.role() = 'authenticated'
);

-- 4. Kullanıcıların kendi yüklediklerini güncelleyebilmesi
CREATE POLICY "Users can update own chat-media files"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'chat-media'
  AND auth.uid()::text = (storage.foldername(name))[2]
);

-- 5. Kullanıcıların kendi yüklediklerini silebilmesi
CREATE POLICY "Users can delete own chat-media files"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'chat-media'
  AND auth.uid()::text = (storage.foldername(name))[2]
);
