import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/core/constants/supabase_config.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/spotify_service.dart';
import 'package:event_match/features/events/models/user_model.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('📅 Tarih Filtreleme (Bugün, Bu Hafta, Bu Ay, Tümü) Testleri', () {
    late MockEventService eventService;

    setUp(() async {
      eventService = MockEventService();
      await eventService.fetchEvents();
    });

    test('Varsayılan tarih filtresi "Tümü" olmalıdır ve tüm ileri tarihli etkinlikler listelenmelidir', () {
      expect(eventService.selectedDateFilter, equals('Tümü'));
      expect(eventService.dateFilters, containsAll(['Tümü', 'Bugün', 'Bu Hafta', 'Bu Ay']));

      final events = eventService.filteredEvents;
      expect(events, isNotEmpty);
      // Sadece bugün değil, gelecek günlerdeki etkinlikler de bulunmalıdır
      final hasFutureEvents = events.any((e) => e.dateTime.isAfter(DateTime.now().add(const Duration(days: 1))));
      expect(hasFutureEvents, isTrue);
    });

    test('Tarih filtresi "Bugün" seçildiğinde sadece bugünün etkinlikleri dönmelidir', () {
      eventService.setDateFilter('Bugün');
      expect(eventService.selectedDateFilter, equals('Bugün'));

      final todayEvents = eventService.filteredEvents;
      expect(todayEvents, isNotEmpty);

      final now = DateTime.now();
      for (final event in todayEvents) {
        final isToday = event.dateTime.year == now.year &&
            event.dateTime.month == now.month &&
            event.dateTime.day == now.day;
        expect(isToday, isTrue, reason: 'Etkinlik tarihi bugün olmalıdır: ${event.title} - ${event.dateTime}');
      }
    });

    test('Tarih filtresi "Bu Hafta" seçildiğinde 7 gün içindeki etkinlikler dönmelidir', () {
      eventService.setDateFilter('Bu Hafta');
      expect(eventService.selectedDateFilter, equals('Bu Hafta'));

      final weekEvents = eventService.filteredEvents;
      expect(weekEvents, isNotEmpty);

      final now = DateTime.now();
      final oneWeekLater = now.add(const Duration(days: 7, hours: 2));

      for (final event in weekEvents) {
        expect(event.dateTime.isBefore(oneWeekLater), isTrue);
      }
    });

    test('Tarih filtresi "Bu Ay" seçildiğinde 30 gün içindeki etkinlikler dönmelidir', () {
      eventService.setDateFilter('Bu Ay');
      expect(eventService.selectedDateFilter, equals('Bu Ay'));

      final monthEvents = eventService.filteredEvents;
      expect(monthEvents, isNotEmpty);

      final now = DateTime.now();
      final oneMonthLater = now.add(const Duration(days: 30, hours: 2));

      for (final event in monthEvents) {
        expect(event.dateTime.isBefore(oneMonthLater), isTrue);
      }
    });
  });

  group('🎵 Spotify Sıla & Aleyna Tilki Eşleşme ve Parça Doğrulama Testleri', () {
    final spotifyService = SpotifyService();

    test('Sıla için Spotify araması başka bir sanatçıya değil, Sıla Gençoğlu profiline ve şarkılarına çözülmelidir', () async {
      final artist = await spotifyService.searchArtist('Sıla', category: 'Konser');
      expect(artist, isNotNull);
      expect(artist!.name.toLowerCase(), contains('sıla'));

      final tracks = await spotifyService.getArtistTopTracks(artist.id, artistName: artist.name);
      expect(tracks, isNotEmpty);
      final titles = tracks.map((t) => t.title.toLowerCase()).toList();
      // Sıla'nın meşhur şarkıları
      expect(titles.any((t) => t.contains('kafa') || t.contains('saki') || t.contains('yan benimle')), isTrue);
    });

    test('Aleyna Tilki için Spotify araması Aleyna Tilki profiline ve hit şarkılarına çözülmelidir', () async {
      final artist = await spotifyService.searchArtist('Aleyna Tilki', category: 'Konser');
      expect(artist, isNotNull);
      expect(artist!.name.toLowerCase(), contains('aleyna'));

      final tracks = await spotifyService.getArtistTopTracks(artist.id, artistName: artist.name);
      expect(tracks, isNotEmpty);
      final titles = tracks.map((t) => t.title.toLowerCase()).toList();
      // Aleyna Tilki'nin hitleri
      expect(titles.any((t) => t.contains('sen olsan bari') || t.contains('cevapsız çınlama') || t.contains('dipsiz')), isTrue);
    });

    test('Etkinlik başlığında organizatör (KerkiSolfej, vb.) olsa bile Sıla doğru çözülmelidir', () async {
      final artist = await spotifyService.searchArtist('Sıla - KerkiSolfej', category: 'Konser');
      expect(artist, isNotNull);
      expect(artist!.name.toLowerCase(), contains('sıla'));
    });
  });

  group('👥 Match Haritası, Doğrulanmış Profil Rozeti ve Eşleşme İsteği Testleri', () {
    test('UserModel konum paylaşım özelliği (enableLocationSharing) varsayılan olarak true olmalıdır', () {
      final user = UserModel(
        id: 'u1',
        name: 'Test Kullanıcı',
        avatarUrl: 'https://example.com/avatar.jpg',
      );
      expect(user.enableLocationSharing, isTrue);
      expect(user.isVerified, isFalse);
    });

    test('UserModel Hayalet Modu (enableLocationSharing = false) toMap ve fromMap ile korunmalıdır', () {
      final user = UserModel(
        id: 'u2',
        name: 'Gizli Kullanıcı',
        avatarUrl: 'https://example.com/avatar2.jpg',
        enableLocationSharing: false,
        latitude: 41.0082,
        longitude: 28.9784,
      );

      final map = user.toMap();
      expect(map['enableLocationSharing'], isFalse);

      final restored = UserModel.fromMap(map);
      expect(restored.enableLocationSharing, isFalse);
      expect(restored.latitude, equals(41.0082));
      expect(restored.longitude, equals(28.9784));
    });

    test('UserModel isVerified özelliği toMap ve fromMap üzerinde başarıyla taşınmalıdır', () {
      final verifiedUser = UserModel(
        id: 'u3',
        name: 'Doğrulanmış Kullanıcı',
        avatarUrl: 'https://example.com/avatar3.jpg',
        isVerified: true,
      );

      final map = verifiedUser.toMap();
      expect(map['is_verified'], isTrue);

      final fromMapUser = UserModel.fromMap(map);
      expect(fromMapUser.isVerified, isTrue);
    });

    test('MockEventService verifyCurrentUserEmail kullanıcının isVerified durumunu ve verified rozetini aktifleştirmelidir', () async {
      final eventService = MockEventService();
      await eventService.fetchEvents();

      // Başlangıçta false olmalı veya kullanıcı henüz doğrulanmamışsa
      expect(eventService.currentUser, isNotNull);
      
      await eventService.verifyCurrentUserEmail('test@eventmatch.com');
      
      expect(eventService.currentUser.isVerified, isTrue);
      expect(eventService.currentUser.badges, contains('verified'));
    });

    test('UserModel birden fazla fotoğraf (avatarUrls) saklayabilmeli ve toMap/fromMap ile korunmalıdır', () {
      final user = UserModel(
        id: 'u4',
        name: 'Fotoğraf Sever',
        avatarUrl: 'https://example.com/p1.jpg',
        avatarUrls: [
          'https://example.com/p1.jpg',
          'https://example.com/p2.jpg',
          'https://example.com/p3.jpg',
        ],
      );

      expect(user.avatarUrls.length, equals(3));
      final map = user.toMap();
      final restored = UserModel.fromMap(map);
      expect(restored.avatarUrls.length, equals(3));
      expect(restored.avatarUrls[1], equals('https://example.com/p2.jpg'));
    });
  });
}
