-- EventMatch Comprehensive Database Schema for Supabase
-- Run this SQL in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  name TEXT,
  username TEXT UNIQUE,
  city TEXT,
  gender TEXT,
  bio TEXT,
  interests JSONB DEFAULT '[]'::jsonb,
  birth_date DATE,
  avatar_url TEXT,
  role TEXT DEFAULT 'user', -- 'user', 'admin', 'moderator'
  hide_last_seen BOOLEAN DEFAULT FALSE,
  is_private BOOLEAN DEFAULT FALSE,
  hide_events BOOLEAN DEFAULT FALSE,
  enable_location_sharing BOOLEAN DEFAULT TRUE,
  is_verified BOOLEAN DEFAULT FALSE,
  show_verified_badge BOOLEAN DEFAULT FALSE,
  is_vip BOOLEAN DEFAULT FALSE,
  vip_expires_at TIMESTAMP WITH TIME ZONE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_online BOOLEAN DEFAULT FALSE,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  points INT DEFAULT 100,
  push_token TEXT,
  fcm_token TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Safe Alter Table additions for existing databases
DO $$
BEGIN
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_verified_badge BOOLEAN DEFAULT FALSE;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_vip BOOLEAN DEFAULT FALSE;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS vip_expires_at TIMESTAMP WITH TIME ZONE;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT FALSE;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 3. USER PROFILES VIEW (For backwards compatibility)
CREATE OR REPLACE VIEW public.user_profiles AS
SELECT * FROM public.users;

-- 4. USER PHOTOS TABLE
CREATE TABLE IF NOT EXISTS public.user_photos (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  storage_url TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. USER SOCIAL LINKS TABLE
CREATE TABLE IF NOT EXISTS public.user_social_links (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. EVENTS TABLE
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
  price TEXT,
  rating DOUBLE PRECISION DEFAULT 0.0,
  review_count INT DEFAULT 0,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  is_user_created BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

DO $$
BEGIN
  ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price TEXT;
  ALTER TABLE public.events ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 0.0;
  ALTER TABLE public.events ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;
  ALTER TABLE public.events ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id) ON DELETE SET NULL;
  ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_user_created BOOLEAN DEFAULT FALSE;
  ALTER TABLE public.events ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 7. EVENT ATTENDEES TABLE
CREATE TABLE IF NOT EXISTS public.event_attendees (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'joined',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. MATCHES TABLE
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

-- 9. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
  id BIGSERIAL PRIMARY KEY,
  match_id BIGINT REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL,
  receiver_id TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. EVENT REVIEWS TABLE (Reviews & Ratings)
CREATE TABLE IF NOT EXISTS public.event_reviews (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  user_name TEXT,
  user_avatar TEXT,
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. USER TICKETS WALLET TABLE
CREATE TABLE IF NOT EXISTS public.user_tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL,
  event_title TEXT NOT NULL,
  event_date TIMESTAMP WITH TIME ZONE,
  event_venue TEXT,
  ticket_code TEXT NOT NULL,
  ticket_type TEXT DEFAULT 'Standart',
  seat_info TEXT,
  qr_data TEXT,
  purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12. AUTH USER REGISTRATION TRIGGER
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, username, birth_date, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Yeni Kullanıcı'),
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
    CASE 
      WHEN (NEW.raw_user_meta_data->>'birth_date') IS NOT NULL AND (NEW.raw_user_meta_data->>'birth_date') != ''
      THEN (NEW.raw_user_meta_data->>'birth_date')::date 
      ELSE NULL 
    END,
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    username = EXCLUDED.username;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO public.users (id, email, name, username, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Yeni Kullanıcı'),
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
    'user'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 13. STORAGE BUCKETS SETUP
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('event-images', 'event-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage Policies for Avatars
DO $$
BEGIN
  DROP POLICY IF EXISTS "Public Avatar Access" ON storage.objects;
  DROP POLICY IF EXISTS "Auth User Avatar Upload" ON storage.objects;
  DROP POLICY IF EXISTS "Auth User Avatar Delete" ON storage.objects;
  
  CREATE POLICY "Public Avatar Access" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
  CREATE POLICY "Auth User Avatar Upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
  CREATE POLICY "Auth User Avatar Delete" ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');

  -- Storage Policies for Chat Media
  DROP POLICY IF EXISTS "Public Chat Media Access" ON storage.objects;
  DROP POLICY IF EXISTS "Auth User Chat Media Upload" ON storage.objects;
  DROP POLICY IF EXISTS "Auth User Chat Media Delete" ON storage.objects;

  CREATE POLICY "Public Chat Media Access" ON storage.objects FOR SELECT USING (bucket_id = 'chat-media');
  CREATE POLICY "Auth User Chat Media Upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'chat-media' AND auth.role() = 'authenticated');
  CREATE POLICY "Auth User Chat Media Delete" ON storage.objects FOR DELETE USING (bucket_id = 'chat-media' AND auth.role() = 'authenticated');

  -- Storage Policies for Event Images
  DROP POLICY IF EXISTS "Public Event Images Access" ON storage.objects;
  DROP POLICY IF EXISTS "Auth User Event Images Upload" ON storage.objects;

  CREATE POLICY "Public Event Images Access" ON storage.objects FOR SELECT USING (bucket_id = 'event-images');
  CREATE POLICY "Auth User Event Images Upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'event-images' AND auth.role() = 'authenticated');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 14. ROW LEVEL SECURITY (RLS) POLICIES FOR TABLES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_social_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tickets ENABLE ROW LEVEL SECURITY;

-- Users policies
DROP POLICY IF EXISTS "Allow read users" ON public.users;
DROP POLICY IF EXISTS "Allow update users" ON public.users;
DROP POLICY IF EXISTS "Allow insert users" ON public.users;
CREATE POLICY "Allow read users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Allow update users" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Allow insert users" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- User photos policies
DROP POLICY IF EXISTS "Allow read user_photos" ON public.user_photos;
DROP POLICY IF EXISTS "Allow manage own user_photos" ON public.user_photos;
CREATE POLICY "Allow read user_photos" ON public.user_photos FOR SELECT USING (true);
CREATE POLICY "Allow manage own user_photos" ON public.user_photos FOR ALL USING (auth.uid() = user_id);

-- User social links policies
DROP POLICY IF EXISTS "Allow read user_social_links" ON public.user_social_links;
DROP POLICY IF EXISTS "Allow manage own user_social_links" ON public.user_social_links;
CREATE POLICY "Allow read user_social_links" ON public.user_social_links FOR SELECT USING (true);
CREATE POLICY "Allow manage own user_social_links" ON public.user_social_links FOR ALL USING (auth.uid() = user_id);

-- Events policies
DROP POLICY IF EXISTS "Allow read events" ON public.events;
DROP POLICY IF EXISTS "Allow authenticated insert events" ON public.events;
DROP POLICY IF EXISTS "Allow authenticated update events" ON public.events;
CREATE POLICY "Allow read events" ON public.events FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert events" ON public.events FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated update events" ON public.events FOR UPDATE USING (auth.role() = 'authenticated');

-- Event attendees policies
DROP POLICY IF EXISTS "Allow read event_attendees" ON public.event_attendees;
DROP POLICY IF EXISTS "Allow manage own event_attendees" ON public.event_attendees;
CREATE POLICY "Allow read event_attendees" ON public.event_attendees FOR SELECT USING (true);
CREATE POLICY "Allow manage own event_attendees" ON public.event_attendees FOR ALL USING (auth.uid() = user_id);

-- Matches policies
DROP POLICY IF EXISTS "Allow read own matches" ON public.matches;
DROP POLICY IF EXISTS "Allow manage own matches" ON public.matches;
CREATE POLICY "Allow read own matches" ON public.matches FOR SELECT USING (auth.uid() = user_id_1 OR auth.uid() = user_id_2);
CREATE POLICY "Allow manage own matches" ON public.matches FOR ALL USING (auth.uid() = user_id_1 OR auth.uid() = user_id_2);

-- Messages policies
DROP POLICY IF EXISTS "Allow read own messages" ON public.messages;
DROP POLICY IF EXISTS "Allow insert own messages" ON public.messages;
DROP POLICY IF EXISTS "Herkes mesaj ekleyebilir" ON public.messages;
DROP POLICY IF EXISTS "Herkes mesajları görebilir" ON public.messages;
CREATE POLICY "Herkes mesaj ekleyebilir" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Herkes mesajları görebilir" ON public.messages FOR SELECT USING (true);

-- Event Reviews policies
DROP POLICY IF EXISTS "Allow read reviews" ON public.event_reviews;
DROP POLICY IF EXISTS "Allow authenticated insert reviews" ON public.event_reviews;
DROP POLICY IF EXISTS "Allow manage own reviews" ON public.event_reviews;
CREATE POLICY "Allow read reviews" ON public.event_reviews FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert reviews" ON public.event_reviews FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow manage own reviews" ON public.event_reviews FOR ALL USING (auth.uid() = user_id);

-- User Tickets policies
DROP POLICY IF EXISTS "Allow read own tickets" ON public.user_tickets;
DROP POLICY IF EXISTS "Allow manage own tickets" ON public.user_tickets;
CREATE POLICY "Allow read own tickets" ON public.user_tickets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Allow manage own tickets" ON public.user_tickets FOR ALL USING (auth.uid() = user_id);

-- 15. ENABLE REALTIME PUBLICATION (Safely add if not already added)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'matches'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'event_attendees'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.event_attendees;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'event_reviews'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.event_reviews;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 16. AFTER PARTY & NEARBY SPOTS TABLE
CREATE TABLE IF NOT EXISTS public.after_party_spots (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'Toplanma Noktası',
  address TEXT,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  note TEXT,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  attendee_names JSONB DEFAULT '[]'::jsonb,
  is_user_created BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.after_party_spots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read after party spots" ON public.after_party_spots;
DROP POLICY IF EXISTS "Allow insert after party spots" ON public.after_party_spots;
CREATE POLICY "Allow read after party spots" ON public.after_party_spots FOR SELECT USING (true);
CREATE POLICY "Allow insert after party spots" ON public.after_party_spots FOR INSERT WITH CHECK (true);

