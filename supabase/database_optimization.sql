-- ==============================================================================
-- EventMatch Veritabanı Optimizasyon, Performans ve Güvenlik Sertleştirme Betiği
-- Bu SQL dosyasını Supabase Dashboard -> SQL Editor üzerinde çalıştırın.
-- ==============================================================================

-- 1. EKSİK İNDEKSLER (Performance & Index Optimization)
-- Mesajlar tablosu indeksleri: Full table scan ve sohbetteki donmaları önler
CREATE INDEX IF NOT EXISTS idx_messages_match_id ON public.messages(match_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver ON public.messages(sender_id, receiver_id);

-- Eşleşmeler tablosu indeksleri
CREATE INDEX IF NOT EXISTS idx_matches_users ON public.matches(user_id_1, user_id_2);
CREATE INDEX IF NOT EXISTS idx_matches_status ON public.matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON public.matches(created_at DESC);

-- Etkinlik katılımcıları indeksleri
CREATE INDEX IF NOT EXISTS idx_event_attendees_event_id ON public.event_attendees(event_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_user_id ON public.event_attendees(user_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_status ON public.event_attendees(status);

-- Etkinlikler filtreleme indeksleri
CREATE INDEX IF NOT EXISTS idx_events_date ON public.events(date);
CREATE INDEX IF NOT EXISTS idx_events_city ON public.events(city);
CREATE INDEX IF NOT EXISTS idx_events_type ON public.events(type);

-- Kullanıcı fotoğrafları indeksleri
CREATE INDEX IF NOT EXISTS idx_user_photos_user_order ON public.user_photos(user_id, sort_order) WHERE is_active = true;

-- 2. ETKİNLİK KATILIMCILARI TEKİLLEŞTİRME VE UNIQUE KISITLAMASI
-- Mükerrer kayıtları temizle (varsa en güncelini koru):
DELETE FROM public.event_attendees a
USING public.event_attendees b
WHERE a.id < b.id 
  AND a.event_id = b.event_id 
  AND a.user_id = b.user_id;

-- Bir kullanıcının aynı etkinliğe mükerrer katılmasını engelleyen kısıtlama ekle:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_event_user_attendance'
  ) THEN
    ALTER TABLE public.event_attendees 
    ADD CONSTRAINT unique_event_user_attendance UNIQUE (event_id, user_id);
  END IF;
END $$;

-- 3. KVKK / GİZLİLİK KORUMASI: PUBLIC_PROFILES VIEW (PII Protection)
-- E-posta, FCM token ve hassas ayarları dışarıda bırakan güvenli genel profil görünümü
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT 
  id, 
  name, 
  username, 
  city, 
  gender, 
  bio, 
  interests, 
  birth_date, 
  avatar_url, 
  points, 
  hide_last_seen,
  is_private,
  hide_events,
  enable_location_sharing,
  created_at
FROM public.users;

-- Yetkileri ver
GRANT SELECT ON public.public_profiles TO authenticated, anon;

-- 4. PUSH DEBUG LOGLARI GÜVENLİĞİ
-- Anonim kullanıcıların bildirim ve kullanıcı kimlik loglarını okumasını engelle
REVOKE ALL ON public.push_debug_logs FROM anon;
GRANT SELECT, INSERT ON public.push_debug_logs TO authenticated, service_role;

-- 5. SAYFALI SWIPE DESTE FONKSİYONU (Server-Side Pagination RPC)
-- İstemcinin tüm kullanıcıları telefona indirmesi yerine sunucuda filtreleyen ve sayfalayan güvenli fonksiyon
CREATE OR REPLACE FUNCTION public.get_swipe_deck(
  p_current_user_id TEXT,
  p_excluded_ids TEXT[] DEFAULT '{}',
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  username TEXT,
  city TEXT,
  gender TEXT,
  bio TEXT,
  interests JSONB,
  birth_date DATE,
  avatar_url TEXT,
  points INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.username,
    u.city,
    u.gender,
    u.bio,
    u.interests,
    u.birth_date,
    u.avatar_url,
    u.points
  FROM public.users u
  WHERE u.id::text <> p_current_user_id
    AND NOT (u.id::text = ANY(p_excluded_ids))
    AND NOT EXISTS (
      -- Zaten eşleşilmiş veya swipe edilmiş kullanıcıları ele
      SELECT 1 FROM public.matches m
      WHERE (m.user_id_1 = p_current_user_id AND m.user_id_2 = u.id::text)
         OR (m.user_id_2 = p_current_user_id AND m.user_id_1 = u.id::text)
    )
  ORDER BY u.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_swipe_deck(TEXT, TEXT[], INT) TO authenticated;
