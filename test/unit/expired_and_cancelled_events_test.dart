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

    test('Biletix: Gerçek Biletix Türkiye kodları (5XXXX formatında) geçerli olmalı, sahte mock kodlar geçersiz sayılmalıdır', () {
      final now = DateTime.now();

      // Gerçek Ticketmaster/Biletix Türkiye etkinlikleri
      final realLiveEvent1 = EventModel(
        id: 'biletix_Z2HyzZyMZk7hv7vve',
        title: 'Ufuk Beydemir',
        category: 'Konser',
        location: 'Holly Stone Performance Hall - Alanya, Antalya',
        dateTime: now.add(const Duration(days: 2)),
        description: 'Ufuk Beydemir konseri',
        imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
        ticketUrl: 'https://www.biletix.com/performance/53Q03/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
      );

      final realLiveEvent2 = EventModel(
        id: 'biletix_Z2HyzZyMZkCjLfvve',
        title: 'Haydaaa! Mehmet Mayda Stand Up',
        category: 'Stand-up',
        location: 'Efsahne Beyoğlu, İstanbul',
        dateTime: now.add(const Duration(days: 3)),
        description: 'Stand up gecesi',
        imageUrl: 'https://images.unsplash.com/photo-1514306191717-452ec28c7814',
        ticketUrl: 'https://www.biletix.com/performance/5MM77/017/TURKIYE/tr',
        ticketProvider: 'Biletix',
      );

      // Sahte/kırık mock etkinlikler (kodlar: ALEYNA, BLACKKEYS)
      final fakeMockEvent1 = EventModel(
        id: 'biletix_fake_1',
        title: 'Eski Sahte Konser',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 4)),
        description: 'Kırık link',
        imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
        ticketUrl: 'https://www.biletix.com/performance/ALEYNA/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
      );

      final fakeMockEvent2 = EventModel(
        id: 'biletix_fake_2',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 5)),
        description: 'Kırık link',
        imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
        ticketUrl: 'https://www.biletix.com/performance/BLACKKEYS/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
      );

      // Gerçek etkinlikler geçerli olmalıdır
      expect(realLiveEvent1.isObsoleteBiletixEvent, isFalse);
      expect(realLiveEvent1.isValidForDisplay, isTrue);
      expect(realLiveEvent1.effectiveTicketUrl, 'https://www.biletix.com/performance/53Q03/001/TURKIYE/tr');

      expect(realLiveEvent2.isObsoleteBiletixEvent, isFalse);
      expect(realLiveEvent2.isValidForDisplay, isTrue);
      expect(realLiveEvent2.effectiveTicketUrl, 'https://www.biletix.com/performance/5MM77/017/TURKIYE/tr');

      // Sahte mock etkinlikler geçersiz olmalıdır
      expect(fakeMockEvent1.isObsoleteBiletixEvent, isTrue);
      expect(fakeMockEvent1.isValidForDisplay, isFalse);

      expect(fakeMockEvent2.isObsoleteBiletixEvent, isTrue);
      expect(fakeMockEvent2.isValidForDisplay, isFalse);
    });

    test('effectiveTicketUrl: Affiliate linklerden u= parametresi doğru çözülmeli veya arama sayfasına yönlendirmelidir', () {
      final now = DateTime.now();

      final affiliateEvent = EventModel(
        id: 'biletix_Z2HyzZyMZk7hv7vve',
        title: 'Ufuk Beydemir',
        category: 'Konser',
        location: 'Antalya',
        dateTime: now.add(const Duration(days: 2)),
        description: 'Konser',
        imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
        ticketUrl: 'https://ticketmaster.evyy.net/c/none/2038774/23908?u=https%3A%2F%2Fwww.biletix.com%2Fperformance%2F53Q03%2F001%2FTURKIYE%2Ftr&utm_medium=affiliate',
        ticketProvider: 'Biletix',
      );

      expect(affiliateEvent.effectiveTicketUrl, 'https://www.biletix.com/performance/53Q03/001/TURKIYE/tr');

      final searchEvent = EventModel(
        id: 'local_duman_live',
        title: 'Duman Konseri',
        category: 'Konser',
        location: 'İstanbul',
        dateTime: now.add(const Duration(days: 3)),
        description: 'Duman',
        imageUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=Duman',
        ticketProvider: 'Biletix',
      );

      expect(searchEvent.effectiveTicketUrl, contains('biletix.com/search/TURKIYE/tr?category=&searchinfo=Duman'));
    });
  });
}
