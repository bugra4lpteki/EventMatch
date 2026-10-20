class ApiKeys {
  // Ticketmaster (Biletix) API Consumer Key
  static const String ticketmasterApiKey = String.fromEnvironment(
    'TICKETMASTER_API_KEY',
    defaultValue: 'fZUp6Yy9cCCrIpa7hJ0diX2eriIvvFjD',
  );

  // Eventbrite API Private Token (Buğrahan Alptekin)
  static const String eventbriteToken = String.fromEnvironment(
    'EVENTBRITE_TOKEN',
    defaultValue: '55L3DDEO35EUK2WCF4IX',
  );

  // Spotify Web API Credentials
  static const String spotifyClientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: 'b59a6fe402284c4a86b16259e8477b8f',
  );

  static const String spotifyClientSecret = String.fromEnvironment(
    'SPOTIFY_CLIENT_SECRET',
    defaultValue: '7d206f47702f430ca3a2d52dc6803e48',
  );

  // Football-Data.org API Token (Buğrahan Alptekin - X-Auth-Token)
  static const String footballDataToken = String.fromEnvironment(
    'FOOTBALL_DATA_TOKEN',
    defaultValue: '7d99783cf97d4a07b806bc78f02af12a',
  );
}
