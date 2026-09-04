import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/widgets/event_card.dart';
import 'package:event_match/features/events/screens/event_detail_screen.dart';
import 'package:event_match/features/events/services/spotify_service.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/mock_match_service.dart';
import 'package:event_match/features/messages/services/mock_message_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/core/constants/supabase_config.dart';

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

  group('1. Spotify Sanatçı vs Tiyatro/Stand-up Filtre Testleri', () {
    final spotifyService = SpotifyService();

    test('Tiyatro etkinliklerinde Spotify sanatçı arama null dönmelidir', () async {
      final res1 = await spotifyService.searchArtist('Amadeus', category: 'Tiyatro');
      expect(res1, isNull, reason: 'Tiyatro etkinliğine Spotify sanatçısı atanmamalı');

      final res2 = await spotifyService.searchArtist('Kel Turne', category: 'theatre');
      expect(res2, isNull, reason: 'Tiyatro etkinliğine Spotify sanatçısı atanmamalı');
    });

    test('Stand-up ve komedi etkinliklerinde Spotify sanatçı arama null dönmelidir', () async {
      final res1 = await spotifyService.searchArtist('Doğu Demirkol', category: 'Stand-up');
      expect(res1, isNull, reason: 'Stand-up etkinliğine Spotify şarkıcısı atanmamalı');

      final res2 = await spotifyService.searchArtist('Baturay Özdemir Stand Up', category: 'Komedi');
      expect(res2, isNull, reason: 'Komedi/Stand-up etkinliğine Spotify şarkıcısı atanmamalı');
    });

    test('Tiyatro ve Stand-up için getArtistImageUrl null dönmelidir', () async {
      final img1 = await spotifyService.getArtistImageUrl('Cimri', category: 'Tiyatro');
      expect(img1, isNull);

      final img2 = await spotifyService.getArtistImageUrl('Doğu Demirkol', category: 'Stand-up');
      expect(img2, isNull);
    });

    test('Sıla için Spotify resmi profil/header kapak görseli dönmelidir (Albüm kapağı değil)', () async {
      final sila = await spotifyService.searchArtist('Sıla', category: 'Konser');
      expect(sila, isNotNull);
      // Resmi Spotify profili Siyah-Beyaz çatı/teras oturan sanatçı görseli
      expect(sila!.imageUrl, equals('https://image-cdn-fa.spotifycdn.com/image/ab6761610000e5ebc6b5e030f9a843e7338bc5f1'));

      final tracks = await spotifyService.getArtistTopTracks(sila.id, artistName: 'Sıla');
      expect(tracks.length, greaterThanOrEqualTo(3));
      expect(tracks[0].title, equals('Kafa'));
      expect(tracks[1].title, equals('Saki'));
      expect(tracks[2].title, equals('Yan Benimle'));
      // Şarkı önizleme ses URL'si kesinlikle boş olmamalı ve çalınabilir olmalıdır
      expect(tracks[0].previewUrl, isNotNull);
      expect(tracks[0].previewUrl, isNotEmpty);
    });

    test('The Sisters of Mercy için grup profil görseli ve şarkı önizlemeleri dönmelidir', () async {
      final som = await spotifyService.searchArtist('The Sisters of Mercy', category: 'Konser');
      expect(som, isNotNull);
      expect(som!.imageUrl, contains('1000x1000-000000-80-0-0.jpg'));

      final tracks = await spotifyService.getArtistTopTracks(som.id, artistName: 'The Sisters of Mercy');
      expect(tracks.length, greaterThanOrEqualTo(3));
      expect(tracks[0].previewUrl, isNotNull);
      expect(tracks[0].previewUrl, isNotEmpty);
    });

    test('Konser ve müzik sanatçılarında Spotify header görseli dönmelidir', () async {
      final buray = await spotifyService.searchArtist('Buray', category: 'Konser');
      expect(buray, isNotNull);
      expect(buray!.imageUrl, contains('ab6761860000101683beeb732a3fc267923707ce'));

      final blackKeys = await spotifyService.searchArtist('The Black Keys', category: 'Konser');
      expect(blackKeys, isNotNull);
      expect(blackKeys!.imageUrl, contains('ab67618600001016d97c724773c3cbdf1fe251b5'));
    });
  });

  group('2. EventModel Görsel Eşleme Testleri', () {
    test('Sıla için Mürekkep albüm kapağı yerine Spotify resmi sanatçı headerı atanmalıdır', () {
      final event = EventModel(
        id: 'sila_1',
        title: 'Sıla Konseri',
        category: 'Konser',
        location: 'CerModern, Ankara',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'Sıla konseri',
        imageUrl: 'https://example.com/murekkep_album.jpg',
      );

      expect(event.imageUrl, equals('https://image-cdn-fa.spotifycdn.com/image/ab6761610000e5ebc6b5e030f9a843e7338bc5f1'));
    });

    test('Hiçbir etkinlik görseli boş (blank) kalmamalıdır', () {
      final emptyEvent = EventModel(
        id: 'empty_1',
        title: 'Bilinmeyen Sanatçı Canlı Performans',
        category: 'Konser',
        location: 'Kadıköy Sahne',
        dateTime: DateTime.now().add(const Duration(days: 5)),
        description: 'Konser',
        imageUrl: '',
      );

      expect(emptyEvent.imageUrl, isNotEmpty);
      expect(emptyEvent.imageUrl, startsWith('http'));
    });

    test('The Black Keys için minivan yerine Spotify grup bannerı atanmalıdır', () {
      final event = EventModel(
        id: 'tbk_1',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'The Black Keys konseri',
        imageUrl: 'https://example.com/minivan.jpg',
      );

      expect(event.imageUrl, contains('ab67618600001016d97c724773c3cbdf1fe251b5'));
    });

    test('Tiyatro ve Stand-up etkinlikleri müzik kapaklarıyla ezilmemelidir', () {
      final tiyatroEvent = EventModel(
        id: 'tiyatro_1',
        title: 'Amadeus Tiyatro Oyunu',
        category: 'Tiyatro',
        location: 'Zorlu PSM',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'Tiyatro',
        imageUrl: 'https://images.tiyatro.com/afis.jpg',
      );

      expect(tiyatroEvent.imageUrl, equals('https://images.tiyatro.com/afis.jpg'));
    });
  });


  group('3. EventCard Rozet ve Buton Testleri', () {
    testWidgets('EventCard üzerinde biletleme firması (BILETIX) yazmamalıdır', (tester) async {
      final event = EventModel(
        id: 'test_card_1',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 20)),
        description: 'Konser',
        imageUrl: 'https://example.com/banner.jpg',
        ticketProvider: 'Biletix',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(event: event),
          ),
        ),
      );

      // Kart üstünde BILETIX rozeti olmamalı
      expect(find.text('BILETIX'), findsNothing);
      expect(find.text('Biletix'), findsNothing);
    });

    testWidgets('EventCard üzerinde "ETKİNLİK" rozeti yazmamalıdır', (tester) async {
      final event = EventModel(
        id: 'test_card_2',
        title: 'Stand-up Gecesi',
        category: 'Stand-up',
        location: 'Kadıköy',
        dateTime: DateTime.now().add(const Duration(days: 30)),
        description: 'Gösteri',
        imageUrl: 'https://example.com/standup.jpg',
        isPopular: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(event: event),
          ),
        ),
      );

      // "✨ ETKİNLİK" veya "ETKİNLİK" rozeti bulunmamalı
      expect(find.text('✨ ETKİNLİK'), findsNothing);
      expect(find.text('ETKİNLİK'), findsNothing);
    });

    testWidgets('EventCard butonu "Biletix Bilet" yerine "Biletler" yazmalıdır', (tester) async {
      final event = EventModel(
        id: 'test_card_3',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 15)),
        description: 'Konser',
        imageUrl: 'https://example.com/banner.jpg',
        ticketProvider: 'Biletix',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(event: event),
          ),
        ),
      );

      // Butonda "Biletix Bilet" değil, sadece "Biletler" olmalı
      expect(find.text('Biletix Bilet'), findsNothing);
      expect(find.text('Bilet Al'), findsNothing);
      expect(find.text('Biletler'), findsOneWidget);
    });
  });

  group('4. EventDetailScreen Tiyatro/Stand-up vs Konser Spotify Ayrımı Testi', () {
    testWidgets('Tiyatro detay ekranında SPOTIFY önizleme alanı bulunmamalıdır', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eventService = MockEventService();
      final tiyatroEvent = EventModel(
        id: 'tiyatro_detail_1',
        title: 'Amadeus',
        category: 'Tiyatro',
        location: 'Zorlu PSM',
        dateTime: DateTime.now().add(const Duration(days: 5)),
        description: 'Tiyatro oyunu',
        imageUrl: 'https://example.com/amadeus.jpg',
        ticketProvider: 'Biletix',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => eventService),
            ChangeNotifierProxyProvider<MockEventService, MockMatchService>(
              create: (_) => MockMatchService(eventService),
              update: (_, es, ms) => ms ?? MockMatchService(es),
            ),
            ChangeNotifierProxyProvider<MockEventService, MockMessageService>(
              create: (_) => MockMessageService(eventService),
              update: (_, es, ms) => ms ?? MockMessageService(es),
            ),
          ],
          child: MaterialApp(
            home: EventDetailScreen(event: tiyatroEvent),
          ),
        ),
      );
      await tester.pump();

      // SPOTIFY başlığı ve şarkı önizleme alanı tiyatroda OLMAMALI
      expect(find.text('SPOTIFY', skipOffstage: false), findsNothing);
      expect(find.text('En Popüler 3 Şarkı', skipOffstage: false), findsNothing);

      // Bilet butonu "BİLETLER" olmalı
      expect(find.text('BİLETLER', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Stand-up detay ekranında SPOTIFY önizleme alanı bulunmamalıdır', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eventService = MockEventService();
      final standupEvent = EventModel(
        id: 'standup_detail_1',
        title: 'Doğu Demirkol',
        category: 'Stand-up',
        location: 'BKM',
        dateTime: DateTime.now().add(const Duration(days: 5)),
        description: 'Stand-up gösterisi',
        imageUrl: 'https://example.com/dogu.jpg',
        ticketProvider: 'Biletinial',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => eventService),
            ChangeNotifierProxyProvider<MockEventService, MockMatchService>(
              create: (_) => MockMatchService(eventService),
              update: (_, es, ms) => ms ?? MockMatchService(es),
            ),
            ChangeNotifierProxyProvider<MockEventService, MockMessageService>(
              create: (_) => MockMessageService(eventService),
              update: (_, es, ms) => ms ?? MockMessageService(es),
            ),
          ],
          child: MaterialApp(
            home: EventDetailScreen(event: standupEvent),
          ),
        ),
      );
      await tester.pump();

      // SPOTIFY başlığı stand-up'ta OLMAMALI
      expect(find.text('SPOTIFY', skipOffstage: false), findsNothing);
      expect(find.text('En Popüler 3 Şarkı', skipOffstage: false), findsNothing);

      // Bilet butonu "BİLETLER" olmalı
      expect(find.text('BİLETLER', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Konser detay ekranında SPOTIFY önizleme alanı bulunmalıdır', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eventService = MockEventService();
      final konserEvent = EventModel(
        id: 'konser_detail_1',
        title: 'Buray',
        category: 'Konser',
        location: 'Harbiye Açıkhava',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'Buray konseri',
        imageUrl: 'https://i.scdn.co/image/ab6761860000101683beeb732a3fc267923707ce',
        ticketProvider: 'Biletix',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => eventService),
            ChangeNotifierProxyProvider<MockEventService, MockMatchService>(
              create: (_) => MockMatchService(eventService),
              update: (_, es, ms) => ms ?? MockMatchService(es),
            ),
            ChangeNotifierProxyProvider<MockEventService, MockMessageService>(
              create: (_) => MockMessageService(eventService),
              update: (_, es, ms) => ms ?? MockMessageService(es),
            ),
          ],
          child: MaterialApp(
            home: EventDetailScreen(event: konserEvent),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // SPOTIFY başlığı ve önizleme alanı konserde OLMALIDIR
      expect(find.text('SPOTIFY', skipOffstage: false), findsOneWidget);
      expect(find.text('En Popüler 3 Şarkı', skipOffstage: false), findsOneWidget);
      expect(find.text('İstersen', skipOffstage: false), findsOneWidget);

      // Bilet butonu "BİLETLER" olmalı
      expect(find.text('BİLETLER', skipOffstage: false), findsOneWidget);
    });
  });
}
