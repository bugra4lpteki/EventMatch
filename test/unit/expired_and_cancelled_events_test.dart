import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/core/constants/supabase_config.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';

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

  group('🚫 Tarihi Geçmiş ve İptal Edilmiş Etkinlik Filtreleme Testleri', () {
    late MockEventService eventService;

    setUp(() async {
      eventService = MockEventService();
      await eventService.fetchEvents();
    });

    test('isExpired: Başlangıç saatinin üzerinden 3 saat geçmiş olan etkinlikler isExpired=true olmalıdır', () {
      final now = DateTime.now();
      
      final pastEvent = EventModel(
        id: 'biletix_past_1',
        title: 'Geçmiş Konser',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.subtract(const Duration(hours: 4)),
        description: 'Tarihi geçmiş konser',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      );

      final ongoingEvent = EventModel(
        id: 'biletix_ongoing_1',
        title: 'Devam Eden Konser',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.subtract(const Duration(hours: 1)),
        description: 'Şu an sahnede olan konser',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      );

      final futureEvent = EventModel(
        id: 'biletix_future_1',
        title: 'Gelecek Konser',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 2)),
        description: 'Gelecek konser',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      );

      expect(pastEvent.isExpired, isTrue);
      expect(pastEvent.isValidForDisplay, isFalse);

      expect(ongoingEvent.isExpired, isFalse);
      expect(ongoingEvent.isValidForDisplay, isTrue);

      expect(futureEvent.isExpired, isFalse);
      expect(futureEvent.isValidForDisplay, isTrue);
    });

    test('isCancelled: İptal edilen veya ertelenen etkinlikler isCancelled=true ve isValidForDisplay=false olmalıdır', () {
      final now = DateTime.now();

      final cancelled1 = EventModel(
        id: 'biletix_c1',
        title: '[İPTAL] Duman Konseri',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 3)),
        description: 'İptal edildi',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      );

      final cancelled2 = EventModel(
        id: 'biletix_c2',
        title: 'Teoman Konseri (İptal Edildi)',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 5)),
        description: 'Etkinlik iptal edilmiştir',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      );

      final postponed = EventModel(
        id: 'biletix_c3',
        title: 'Mor ve Ötesi [ERTELENDİ]',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 7)),
        description: 'Ertelendi',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      );

      expect(cancelled1.isCancelled, isTrue);
      expect(cancelled1.isValidForDisplay, isFalse);

      expect(cancelled2.isCancelled, isTrue);
      expect(cancelled2.isValidForDisplay, isFalse);

      expect(postponed.isCancelled, isTrue);
      expect(postponed.isValidForDisplay, isFalse);
    });

    test('filteredEvents ve getCarouselEvents tarihi geçmiş veya iptal edilmiş etkinlikleri asla döndürmemelidir', () {
      final now = DateTime.now();

      // Tarihi geçmiş etkinlik ekle
      eventService.addEvent(EventModel(
        id: 'test_expired_event',
        title: 'Eski Tarihli Konser',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.subtract(const Duration(days: 2)),
        description: '2 gün önceki konser',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      ));

      // İptal edilmiş etkinlik ekle
      eventService.addEvent(EventModel(
        id: 'test_cancelled_event',
        title: '[İPTAL] Gelecek Konser',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 3)),
        description: 'İptal',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      ));

      final filtered = eventService.filteredEvents;
      final carousel = eventService.getCarouselEvents();
      final all = eventService.allEvents;

      expect(filtered.any((e) => e.id == 'test_expired_event'), isFalse);
      expect(filtered.any((e) => e.id == 'test_cancelled_event'), isFalse);

      expect(carousel.any((e) => e.id == 'test_expired_event'), isFalse);
      expect(carousel.any((e) => e.id == 'test_cancelled_event'), isFalse);

      expect(all.any((e) => e.id == 'test_expired_event'), isFalse);
      expect(all.any((e) => e.id == 'test_cancelled_event'), isFalse);
    });
  });
}
