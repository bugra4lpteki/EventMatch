class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pqtpogebnfubrqowlnkq.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxdHBvZ2VibmZ1YnJxb3dsbmtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwNjM4NjMsImV4cCI6MjEwMDYzOTg2M30.jHzTJadRqvmrlGGjkFZ9qNUKNi_2CatfBGUxCZ_cn6o',
  );
}
