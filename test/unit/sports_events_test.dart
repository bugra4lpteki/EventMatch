import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/external_event_service.dart';
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

  group('🚫 Spor Müsabakalarının Uygulamadan Kaldırılması Testleri', () {
    test('Kategori listesinde kesinlikle Spor veya Müsabaka seçeneği bulunmamalıdır', () {
      final eventService = MockEventService();
      expect(eventService.categories.contains('Spor'), isFalse);
      expect(eventService.categories.any((c) => c.toLowerCase().contains('spor')), isFalse);
      expect(eventService.categories.any((c) => c.toLowerCase().contains('musabaka')), isFalse);
      expect(eventService.categories, containsAll(['Tümü', 'Konser', 'Tiyatro', 'Stand-up', 'Festival']));
    });

    test('addCategory fonksiyonu ile Spor veya Müsabaka eklenememelidir', () {
      final eventService = MockEventService();
      eventService.addCategory('Spor');
      eventService.addCategory('⚽ Spor Müsabakaları');
      eventService.addCategory('Futbol Maçı');

      expect(eventService.categories.contains('Spor'), isFalse);
      expect(eventService.categories.contains('⚽ Spor Müsabakaları'), isFalse);
    });

    test('MockEventService içerisine spor etkinliği girse dahi filteredEvents ve allEvents tarafından elenmelidir', () {
      final eventService = MockEventService();
      
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

      eventService.addEvent(concertEvent);
      eventService.addEvent(derbyEvent);

      final filtered = eventService.filteredEvents;
      expect(filtered.any((e) => e.id == derbyEvent.id), isFalse);
      expect(filtered.any((e) => e.id == concertEvent.id), isTrue);

      final all = eventService.allEvents;
      expect(all.any((e) => e.id == derbyEvent.id), isFalse);

      final admin = eventService.getAdminEvents();
      expect(admin.any((e) => e.id == derbyEvent.id), isFalse);
    });

    test('ExternalEventService fetchLiveSportsEvents boş liste döndürmelidir', () async {
      final externalService = ExternalEventService();
      final sports = await externalService.fetchLiveSportsEvents();
      expect(sports, isEmpty);
    });

    test('Fallback vitrin etkinlikleri arasında hiçbir spor müsabakası bulunmamalıdır', () async {
      final eventService = MockEventService();
      await eventService.fetchEvents();

      final events = eventService.allEvents;
      expect(events.isNotEmpty, isTrue);
      expect(events.any((e) => e.isSportsEvent), isFalse);
      expect(events.any((e) => e.category.toLowerCase().contains('spor')), isFalse);
    });
  });
}
