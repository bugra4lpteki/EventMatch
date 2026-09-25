-- ==============================================================================
-- EventMatch Veritabanı Optimizasyon, Performans ve Güvenlik Sertleştirme Betiği (v2 - Hata Korumalı)
-- Bu SQL dosyasını Supabase Dashboard -> SQL Editor üzerinde çalıştırın.
-- ==============================================================================

-- 1. TABLOLARIN VE GEREKLİ TÜM KOLONLARIN VARLIĞINI GARANTİYE AL (Zero-Error Column Guards)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  name TEXT,
  username TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS interests JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS points INT DEFAULT 100;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS hide_last_seen BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS hide_events BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS enable_location_sharing BOOLEAN DEFAULT TRUE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS public.user_photos (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  storage_url TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT DEFAULT 'Genel',
  venue TEXT,
  city TEXT,
  date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT,
  image_url TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  tag TEXT,
  ticket_url TEXT,
  ticket_provider TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.event_attendees (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'joined',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.matches (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT,
  user_id_1 TEXT NOT NULL,
  user_id_2 TEXT NOT NULL,
  action_1 TEXT,
  action_2 TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id BIGSERIAL PRIMARY KEY,
  match_id BIGINT REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL,
  receiver_id TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.push_debug_logs (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  status TEXT,
  details JSONB
);

-- 2. ETKİNLİK KATILIMCILARI TEKİLLEŞTİRME VE UNIQUE KISITLAMASI
DELETE FROM public.event_attendees a
USING public.event_attendees b
WHERE a.id < b.id 
  AND a.event_id = b.event_id 
  AND a.user_id = b.user_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'unique_event_user_attendance'
  ) THEN
    ALTER TABLE public.event_attendees 
    ADD CONSTRAINT unique_event_user_attendance UNIQUE (event_id, user_id);
  END IF;
END $$;

-- 3. EKSİK İNDEKSLER (Performance & Index Optimization)
CREATE INDEX IF NOT EXISTS idx_messages_match_id ON public.messages(match_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver ON public.messages(sender_id, receiver_id);

CREATE INDEX IF NOT EXISTS idx_matches_users ON public.matches(user_id_1, user_id_2);
CREATE INDEX IF NOT EXISTS idx_matches_status ON public.matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON public.matches(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_event_attendees_event_id ON public.event_attendees(event_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_user_id ON public.event_attendees(user_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_status ON public.event_attendees(status);

CREATE INDEX IF NOT EXISTS idx_events_date ON public.events(date);
CREATE INDEX IF NOT EXISTS idx_events_city ON public.events(city);
CREATE INDEX IF NOT EXISTS idx_events_type ON public.events(type);

CREATE INDEX IF NOT EXISTS idx_user_photos_user_order ON public.user_photos(user_id, sort_order) WHERE is_active = true;

-- 4. KVKK / GİZLİLİK KORUMASI: PUBLIC_PROFILES VIEW (PII Protection)
-- u.avatar_url boşsa user_photos tablosundaki ilk aktif fotoğrafı otomatik bağlar
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT 
  u.id, 
  u.name, 
  u.username, 
  u.city, 
  u.gender, 
  u.bio, 
  u.interests, 
  u.birth_date, 
  COALESCE(
    u.avatar_url, 
    (SELECT p.storage_url FROM public.user_photos p WHERE p.user_id = u.id AND p.is_active = true ORDER BY p.sort_order ASC LIMIT 1),
    ''
  ) AS avatar_url, 
  COALESCE(u.points, 100) AS points, 
  COALESCE(u.hide_last_seen, false) AS hide_last_seen,
  COALESCE(u.is_private, false) AS is_private,
  COALESCE(u.hide_events, false) AS hide_events,
  COALESCE(u.enable_location_sharing, true) AS enable_location_sharing,
  u.created_at
FROM public.users u;

GRANT SELECT ON public.public_profiles TO authenticated, anon;

-- 5. PUSH DEBUG LOGLARI GÜVENLİĞİ
REVOKE ALL ON public.push_debug_logs FROM anon;
GRANT SELECT, INSERT ON public.push_debug_logs TO authenticated, service_role;

-- 6. SAYFALI SWIPE DESTE FONKSİYONU (Server-Side Pagination RPC)
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
    COALESCE(
      u.avatar_url, 
      (SELECT p.storage_url FROM public.user_photos p WHERE p.user_id = u.id AND p.is_active = true ORDER BY p.sort_order ASC LIMIT 1),
      ''
    ) AS avatar_url,
    COALESCE(u.points, 100) AS points
  FROM public.users u
  WHERE u.id::text <> p_current_user_id
    AND NOT (u.id::text = ANY(p_excluded_ids))
    AND NOT EXISTS (
      SELECT 1 FROM public.matches m
      WHERE (m.user_id_1 = p_current_user_id AND m.user_id_2 = u.id::text)
         OR (m.user_id_2 = p_current_user_id AND m.user_id_1 = u.id::text)
    )
  ORDER BY u.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_swipe_deck(TEXT, TEXT[], INT) TO authenticated;
