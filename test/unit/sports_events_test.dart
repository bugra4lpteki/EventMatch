import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/services/sports_api_service.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/mock_match_service.dart';
import 'package:event_match/features/messages/services/mock_message_service.dart';
import 'package:event_match/features/events/widgets/event_card.dart';
import 'package:event_match/features/events/screens/event_detail_screen.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('⚽ API-Sports & Biletsiz Müsabaka Mantığı Testleri', () {
    test('Spor müsabakalarında isSportsEvent true ve bilet bilgileri boş olmalıdır', () {
      final sportEvent = EventModel(
        id: 'spor_derbi_1',
        title: 'Galatasaray - Fenerbahçe',
        category: '⚽ Spor Müsabakaları',
        location: 'RAMS Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        description: 'Trendyol Süper Lig maçı.',
        imageUrl: 'https://example.com/derbi.jpg',
        ticketUrl: 'https://www.passo.com.tr', // Dışarıdan verilse bile sıfırlanmalı
        ticketProvider: 'Passo',
      );

      expect(sportEvent.isSportsEvent, isTrue);
      // KURAL: Spor müsabakalarında bilet yönlendirmesi kesinlikle yapılmaz
      expect(sportEvent.effectiveTicketUrl, isEmpty);
      expect(sportEvent.effectiveTicketProvider, isEmpty);
      expect(sportEvent.hasTicket, isFalse);
    });

    test('Konser ve sanat etkinliklerinde bilet bilgileri normal korunmalıdır', () {
      final concertEvent = EventModel(
        id: 'biletix_duman_1',
        title: 'Duman Konseri',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'Duman canlı performans.',
        imageUrl: 'https://example.com/duman.jpg',
        ticketUrl: 'https://www.biletix.com/performance/12345',
        ticketProvider: 'Biletix',
      );

      expect(concertEvent.isSportsEvent, isFalse);
      expect(concertEvent.effectiveTicketUrl.contains('biletix.com'), isTrue);
      expect(concertEvent.effectiveTicketProvider, equals('Biletix'));
      expect(concertEvent.hasTicket, isTrue);
    });

    test('SportsApiService tarafından üretilen tüm müsabakalar biletsiz olmalıdır', () async {
      final apiService = SportsApiService();
      final fixtures = await apiService.fetchAllSportsEvents();

      expect(fixtures.isNotEmpty, isTrue);
      for (final ev in fixtures) {
        expect(ev.isSportsEvent, isTrue);
        expect(ev.ticketUrl, isNull);
        expect(ev.ticketProvider, isNull);
        expect(ev.effectiveTicketUrl, isEmpty);
        expect(ev.effectiveTicketProvider, isEmpty);
      }
    });

    test('Spor müsabakalarının tarihleri geçmiş olmamalı ve gerçekçi başlama saatlerinde olmalıdır', () async {
      final apiService = SportsApiService();
      final fixtures = await apiService.fetchAllSportsEvents();

      final now = DateTime.now();
      expect(fixtures.isNotEmpty, isTrue);
      for (final ev in fixtures) {
        // Müsabaka tarihi geçmiş olmamalıdır (en fazla 3 saatlik oynanan maç toleransı hariç)
        expect(ev.dateTime.isAfter(now.subtract(const Duration(hours: 3))), isTrue,
            reason: '${ev.title} müsabakasının tarihi (${ev.dateTime}) geçmişte görünüyor!');

        // Müsabaka başlama saati gece 02:00 veya sabah 05:00 gibi absürt saatlerde olmamalıdır (12:00 ile 23:00 arası)
        expect(ev.dateTime.hour >= 12 && ev.dateTime.hour <= 23, isTrue,
            reason: '${ev.title} müsabakasının saati (${ev.dateTime.hour}:${ev.dateTime.minute}) gerçekçi değil!');
      }
    });

    test('Spor Müsabakaları veya Tüm Müsabakalar seçildiğinde kültürel etkinlikler (müze, konser vb.) kesinlikle listelenmemelidir', () {
      final eventService = MockEventService();
      
      // Müze, konser ve spor müsabakası ekle
      final museumEvent = EventModel(
        id: 'biletix_antalya_kum_heykeli',
        title: 'Antalya Kum Heykel Müzesi - 2026',
        category: 'Miscellaneous',
        location: 'Antalya Kum Heykel Müzesi, Antalya',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        description: 'Uluslararası kum heykel festivali.',
        imageUrl: 'https://example.com/muze.jpg',
        ticketUrl: 'https://www.biletix.com/performance/111',
        ticketProvider: 'Biletix',
      );
      final concertEvent = EventModel(
        id: 'biletix_duman_konseri',
        title: 'Duman - Canlı Performans',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        description: 'Duman rock konseri.',
        imageUrl: 'https://example.com/duman.jpg',
        ticketUrl: 'https://www.biletix.com/performance/222',
        ticketProvider: 'Biletix',
      );
      final derbyEvent = EventModel(
        id: 'spor_apisports_gs_fb_test',
        title: 'Galatasaray - Fenerbahçe',
        category: '⚽ Spor Müsabakaları',
        location: 'RAMS Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 4)),
        description: 'Derbi maçı.',
        imageUrl: 'https://example.com/derbi.jpg',
      );

      eventService.addEvent(museumEvent);
      eventService.addEvent(concertEvent);
      eventService.addEvent(derbyEvent);

      // ⚽ Spor Müsabakaları kategorisi seçildiğinde
      eventService.setCategory('⚽ Spor Müsabakaları');
      final sportsList = eventService.filteredEvents;

      // Müze ve konser kesinlikle filtrelenmeli, yalnızca spor müsabakaları kalmalı
      expect(sportsList.any((e) => e.title.contains('Antalya Kum Heykel Müzesi')), isFalse);
      expect(sportsList.any((e) => e.title.contains('Duman')), isFalse);
      expect(sportsList.any((e) => e.id == museumEvent.id), isFalse);
      expect(sportsList.any((e) => e.id == concertEvent.id), isFalse);
      expect(sportsList.every((e) => e.isSportsEvent), isTrue);
    });

    test('Spor alt filtreleri yalnızca futbol müsabakalarını içermelidir (basketbol, voleybol, tenis kaldırılmıştır)', () async {
      final eventService = MockEventService();
      await eventService.fetchEvents();
      expect(MockEventService.sportsSubFilters, containsAll(['Tümü', '⚽ Futbol', '🇹🇷 Süper Lig', '🏆 Avrupa Ligleri']));
      expect(MockEventService.sportsSubFilters.any((s) => s.contains('Basketbol') || s.contains('Voleybol') || s.contains('Tenis')), isFalse);

      eventService.setCategory('Spor');

      // ⚽ Futbol testi
      eventService.setSportsSubFilter('⚽ Futbol');
      final footballEvents = eventService.filteredEvents;
      expect(footballEvents.isNotEmpty, isTrue);
      expect(footballEvents.any((e) => e.title.contains('ATP') || e.title.contains('VakıfBank') || e.title.contains('Panathinaikos')), isFalse);

      // 🇹🇷 Süper Lig testi
      eventService.setSportsSubFilter('🇹🇷 Süper Lig');
      final superLigEvents = eventService.filteredEvents;
      expect(superLigEvents.isNotEmpty, isTrue);
      expect(superLigEvents.any((e) => e.title.contains('Galatasaray') || e.title.contains('Fenerbahçe')), isTrue);

      // Basketbol, Voleybol ve Tenis müsabakaları kesinlikle bulunmamalıdır
      expect(footballEvents.any((e) => e.title.contains('Efes') || e.title.contains('Eczacıbaşı') || e.title.contains('Challenger')), isFalse);
    });

    testWidgets('EventCard spor müsabakası için bilet butonu yerine Müsabaka butonu göstermelidir', (tester) async {
      final sportEvent = EventModel(
        id: 'spor_fb_gs_card_test',
        title: 'Fenerbahçe - Galatasaray',
        category: '⚽ Spor Müsabakaları',
        location: 'Ülker Stadyumu Şükrü Saracoğlu, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 4)),
        description: 'Trendyol Süper Lig derbisi.',
        imageUrl: 'https://example.com/derbi.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(event: sportEvent),
          ),
        ),
      );

      // Kart üzerinde "Müsabaka" yazmalı, herhangi bir bilet firması adı (Biletix, Passo vb.) yazmamalıdır
      expect(find.text('Müsabaka'), findsOneWidget);
      expect(find.text('Biletix'), findsNothing);
      expect(find.text('Passo'), findsNothing);
      expect(find.text('Bilet Al'), findsNothing);
    });

    testWidgets('EventDetailScreen spor müsabakasında Bilet Al butonu göstermemelidir', (tester) async {
      final sportEvent = EventModel(
        id: 'spor_bjk_ts_detail_test',
        title: 'Beşiktaş - Trabzonspor',
        category: '⚽ Spor Müsabakaları',
        location: 'Tüpraş Stadyumu, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 5)),
        description: 'Süper Lig zirve maçı.',
        imageUrl: 'https://example.com/bjk_ts.jpg',
      );

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eventService = MockEventService();
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
            home: EventDetailScreen(event: sportEvent),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // "Ben de Geliyorum" butonu olmalı
      expect(find.text('Ben de Geliyorum', skipOffstage: false), findsOneWidget);

      // "Bilet Al", "Passo'dan Bilet Al" veya "Bilet Satın Al" butonu kesinlikle bulunmamalıdır
      expect(find.textContaining('Bilet Al', skipOffstage: false), findsNothing);
      expect(find.textContaining('Bilet Satın Al', skipOffstage: false), findsNothing);
      expect(find.textContaining('bilet yönlendirmesi yapılmamaktadır', skipOffstage: false), findsOneWidget);
    });
  });
}
