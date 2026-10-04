-- ==============================================================================
-- EventMatch: Moderasyon, Şikayet ve Engelleme Tabloları (Apple Guideline 1.2)
-- Supabase SQL Editor'de çalıştırarak tabloları oluşturabilirsiniz.
-- ==============================================================================

-- 1. Kullanıcı Engelleme Tablosu (user_blocks)
CREATE TABLE IF NOT EXISTS public.user_blocks (
  id BIGSERIAL PRIMARY KEY,
  blocker_id TEXT NOT NULL,
  blocked_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks(blocked_id);

GRANT ALL ON public.user_blocks TO anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- 2. Kullanıcı Şikayetleri Tablosu (user_reports)
CREATE TABLE IF NOT EXISTS public.user_reports (
  id BIGSERIAL PRIMARY KEY,
  reporter_id TEXT NOT NULL,
  reported_user_id TEXT NOT NULL,
  reported_user_name TEXT,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending_review',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_reports_status ON public.user_reports(status);
GRANT ALL ON public.user_reports TO anon, authenticated, service_role;

-- 3. Etkinlik Şikayetleri Tablosu (event_reports)
CREATE TABLE IF NOT EXISTS public.event_reports (
  id BIGSERIAL PRIMARY KEY,
  reporter_id TEXT NOT NULL,
  reported_event_id TEXT NOT NULL,
  event_title TEXT,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending_review',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_reports_status ON public.event_reports(status);
GRANT ALL ON public.event_reports TO anon, authenticated, service_role;

-- 4. Mesaj Şikayetleri Tablosu (message_reports)
CREATE TABLE IF NOT EXISTS public.message_reports (
  id BIGSERIAL PRIMARY KEY,
  reporter_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_name TEXT,
  content TEXT,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending_review',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_message_reports_status ON public.message_reports(status);
GRANT ALL ON public.message_reports TO anon, authenticated, service_role;
