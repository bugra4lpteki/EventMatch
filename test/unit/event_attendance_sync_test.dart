import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/models/user_model.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/mock_match_service.dart';
import 'package:event_match/features/events/widgets/event_card.dart';
import 'package:event_match/features/events/screens/event_detail_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.mock',
      );
    } catch (_) {}
  });

  group('Etkinlik Katılımı ve Katılımcı Senkronizasyon Testleri', () {
    test('Kullanıcı etkinliğe katıldığında plannedEvents ve attendees güncellenmelidir', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MockEventService();
      
      final testEvent = EventModel(
        id: 'the_black_keys_test_1',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'The Black Keys Konseri',
        imageUrl: 'https://example.com/banner.jpg',
        attendees: [],
      );

      // Başlangıçta katılımcı yok
      expect(service.isUserAttending(testEvent.id), isFalse);

      // Etkinliğe katıl
      await service.joinEvent(testEvent.id, testEvent);

      // Katılım durumu aktif olmalı
      expect(service.isUserAttending(testEvent.id), isTrue);

      final liveEvent = service.getEventById(testEvent.id);
      expect(liveEvent, isNotNull);
      expect(liveEvent!.attendees.length, equals(1));
      expect(liveEvent.attendees.first.id, equals(service.currentUserId));
    });

    testWidgets('EventCard katılım yapıldığında "Sen katılıyorsun" göstermelidir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = MockEventService();
      
      final testEvent = EventModel(
        id: 'the_black_keys_card_1',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'The Black Keys Konseri',
        imageUrl: 'https://example.com/banner.jpg',
        attendees: [],
      );

      // 1. Katılmadan önce: "İlk katılan sen ol" yazmalı
      await tester.pumpWidget(
        ChangeNotifierProvider<MockEventService>.value(
          value: service,
          child: MaterialApp(
            home: Scaffold(
              body: EventCard(event: testEvent),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('İlk katılan sen ol'), findsOneWidget);

      // 2. Etkinliğe katılınca: "Sen katılıyorsun" yazmalı, "İlk katılan sen ol" kalkmalı
      await service.joinEvent(testEvent.id, testEvent);
      await tester.pumpAndSettle();

      expect(find.text('Sen katılıyorsun'), findsOneWidget);
      expect(find.text('İlk katılan sen ol'), findsNothing);
    });

    testWidgets('EventDetailScreen katılım sonrası "0 Kişi" ve "Henüz kimse katılmadı" göstermemelidir', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final eventService = MockEventService();
      final matchService = MockMatchService(eventService);

      final testEvent = EventModel(
        id: 'the_black_keys_detail_1',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 10)),
        description: 'The Black Keys Konseri',
        imageUrl: 'https://example.com/banner.jpg',
        attendees: [],
      );

      await eventService.joinEvent(testEvent.id, testEvent);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MockEventService>.value(value: eventService),
            ChangeNotifierProvider<MockMatchService>.value(value: matchService),
          ],
          child: MaterialApp(
            home: EventDetailScreen(event: testEvent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "0 Kişi" yazmamalı, "1 Kişi" yazmalı
      expect(find.text('0 Kişi'), findsNothing);
      expect(find.text('1 Kişi'), findsOneWidget);

      // "Henüz kimse katılmadı. İlk katılan sen ol!" yazmamalı
      expect(find.text('Henüz kimse katılmadı. İlk katılan sen ol!'), findsNothing);

      // Kullanıcının adı ve "SEN" rozeti görünmeli
      expect(find.text('SEN'), findsOneWidget);
      expect(find.textContaining('(Sen)'), findsOneWidget);
    });
  });
}
