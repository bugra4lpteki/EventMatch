-- EventMatch Database Schema for Supabase
-- Run this SQL in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. ENABLE UUID EXTENSION
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  username TEXT UNIQUE,
  city TEXT,
  gender TEXT,
  bio TEXT,
  interests JSONB DEFAULT '[]'::jsonb,
  birth_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- 7. EVENT ATTENDEES TABLE
CREATE TABLE IF NOT EXISTS public.event_attendees (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'joined',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- 8. MATCHES TABLE
CREATE TABLE IF NOT EXISTS public.matches (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  user_id_1 UUID REFERENCES public.users(id) ON DELETE CASCADE,
  user_id_2 UUID REFERENCES public.users(id) ON DELETE CASCADE,
  action_1 TEXT,
  action_2 TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
  id BIGSERIAL PRIMARY KEY,
  match_id BIGINT REFERENCES public.matches(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. AUTH USER REGISTRATION TRIGGER
-- Automatically creates a public.users entry when a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, username, birth_date)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Yeni Kullanıcı'),
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
    CASE 
      WHEN (NEW.raw_user_meta_data->>'birth_date') IS NOT NULL AND (NEW.raw_user_meta_data->>'birth_date') != ''
      THEN (NEW.raw_user_meta_data->>'birth_date')::date 
      ELSE NULL 
    END
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    username = EXCLUDED.username;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO public.users (id, name, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Yeni Kullanıcı'),
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 11. STORAGE BUCKET setup (Run this SQL or enable in Supabase UI -> Storage)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policy: Allow public read access to avatars
CREATE POLICY "Public Avatar Access" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

-- Storage Policy: Allow authenticated users to upload avatars
CREATE POLICY "Auth User Avatar Upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- Storage Policy: Allow authenticated users to delete avatars
CREATE POLICY "Auth User Avatar Delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- 12. ROW LEVEL SECURITY (RLS) POLICIES FOR TABLES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_social_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Allow read users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Allow update users" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Allow insert users" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- User photos policies
CREATE POLICY "Allow read user_photos" ON public.user_photos FOR SELECT USING (true);
CREATE POLICY "Allow manage own user_photos" ON public.user_photos FOR ALL USING (auth.uid() = user_id);

-- User social links policies
CREATE POLICY "Allow read user_social_links" ON public.user_social_links FOR SELECT USING (true);
CREATE POLICY "Allow manage own user_social_links" ON public.user_social_links FOR ALL USING (auth.uid() = user_id);

-- Events policies
CREATE POLICY "Allow read events" ON public.events FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert events" ON public.events FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated update events" ON public.events FOR UPDATE USING (auth.role() = 'authenticated');

-- Event attendees policies
CREATE POLICY "Allow read event_attendees" ON public.event_attendees FOR SELECT USING (true);
CREATE POLICY "Allow manage own event_attendees" ON public.event_attendees FOR ALL USING (auth.uid() = user_id);

-- Matches policies
CREATE POLICY "Allow read own matches" ON public.matches FOR SELECT USING (auth.uid() = user_id_1 OR auth.uid() = user_id_2);
CREATE POLICY "Allow manage own matches" ON public.matches FOR ALL USING (auth.uid() = user_id_1 OR auth.uid() = user_id_2);

-- Messages policies
CREATE POLICY "Allow read own messages" ON public.messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Allow insert own messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- SAMPLE EVENTS DATA INSERT (Opsiyonel Örnek Veriler)
INSERT INTO public.events (id, title, type, venue, city, date, description, image_url, lat, lng, tag)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Yaz Festivali Konseri', 'Müzik', 'KüçükÇiftlik Park', 'İstanbul', NOW() + INTERVAL '2 days', 'Yazın en büyük açık hava konseri!', 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745', 41.0415, 28.9925, 'Popüler'),
  ('22222222-2222-2222-2222-222222222222', 'Açık Hava Sineması', 'Sinema', 'Zorlu PSM', 'İstanbul', NOW() + INTERVAL '5 days', 'Nostaljik açık hava sinema gecesi.', 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba', 41.0664, 29.0171, 'Sakin'),
  ('33333333-3333-3333-3333-333333333333', 'Tech & AI Summit', 'Teknoloji', 'Kolektif House', 'İstanbul', NOW() + INTERVAL '10 days', 'Yapay zeka ve teknoloji dünyasından konuşmacılar.', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87', 41.0782, 29.0118, 'Teknoloji')
ON CONFLICT (id) DO NOTHING;
