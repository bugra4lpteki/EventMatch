import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/core/services/quick_actions_service.dart';
import 'package:event_match/core/services/spotlight_search_service.dart';
import 'package:event_match/core/services/in_app_review_service.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/models/user_model.dart';
import 'package:event_match/features/events/widgets/apple_wallet_pass_sheet.dart';
import 'package:event_match/features/events/widgets/event_vibe_guide_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    id: 'user_test_apple_1',
    name: 'Alp Tekin',
    avatarUrl: '',
    city: 'İstanbul',
    birthDate: DateTime(2000, 1, 1),
    tags: ['Rock', 'Konser'],
    isVip: true,
  );

  final testRockEvent = EventModel(
    id: 'rock_event_1',
    title: 'Duman Harbiye Konseri',
    category: 'Rock',
    location: 'Harbiye Cemil Topuzlu Açıkhava Tiyatrosu',
    dateTime: DateTime(2026, 10, 15, 21, 0),
    description: 'Büyük Harbiye Rock Konseri',
    imageUrl: 'https://example.com/duman.jpg',
    attendees: [],
  );

  final testTechnoEvent = EventModel(
    id: 'techno_event_1',
    title: 'Afterlife İstanbul',
    category: 'Elektronik & Techno',
    location: 'Zorlu PSM',
    dateTime: DateTime(2026, 11, 20, 23, 0),
    description: 'Techno Rave Gecesi',
    imageUrl: 'https://example.com/techno.jpg',
    attendees: [],
  );

  final testFestivalEvent = EventModel(
    id: 'festival_event_1',
    title: 'Chill-Out Festival',
    category: 'Festival',
    location: 'Kemer Golf & Country Club Park',
    dateTime: DateTime(2026, 9, 5, 14, 0),
    description: 'Açık hava festivali',
    imageUrl: 'https://example.com/festival.jpg',
    attendees: [],
  );

  group('1. Apple Ecosystem Core Services Tests', () {
    test('QuickActionsService singleton exists and triggers callbacks', () {
      final service = QuickActionsService();
      expect(service, isNotNull);

      String? triggered;
      QuickActionsService.onShortcutTapped = (shortcut) {
        triggered = shortcut;
      };

      QuickActionsService.onShortcutTapped?.call('shortcut_radar');
      expect(triggered, equals('shortcut_radar'));

      QuickActionsService.onShortcutTapped?.call('shortcut_vip');
      expect(triggered, equals('shortcut_vip'));

      QuickActionsService.onShortcutTapped = null;
    });

    test('SpotlightSearchService singleton exists and methods execute safely', () async {
      final spotlight = SpotlightSearchService();
      expect(spotlight, isNotNull);

      await spotlight.indexEvent(testRockEvent);
      await spotlight.deindexEvent(testRockEvent.id);
    });

    test('InAppReviewService singleton tracks attendance and ticket purchase', () async {
      final review = InAppReviewService();
      expect(review, isNotNull);

      await review.triggerEventAttendedReview();
      await review.triggerTicketPurchaseReview();
    });
  });

  group('2. Apple Wallet Pass Sheet (PKPass) Widget Tests', () {
    testWidgets('AppleWalletPassSheet mounts and renders ticket details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppleWalletPassSheet(
              event: testRockEvent,
              user: testUser,
            ),
          ),
        ),
      );

      // Animation repeats, so pump finite time instead of pumpAndSettle
      await tester.pump(const Duration(milliseconds: 100));

      // Check title and category
      expect(find.text('Duman Harbiye Konseri'), findsOneWidget);
      expect(find.text('Harbiye Cemil Topuzlu Açıkhava Tiyatrosu'), findsOneWidget);
      expect(find.text('ROCK'), findsOneWidget);
      expect(find.text('VIP PASS 👑'), findsOneWidget);
      expect(find.text('Alp Tekin'), findsOneWidget);
      expect(find.text('Doğrulanmış Katılımcı'), findsOneWidget);
      expect(find.text('GEÇERLİ BİLET'), findsOneWidget);
      expect(find.text('Apple Cüzdan\'a Ekle'), findsOneWidget);
      expect(find.text('Bileti Arkadaşınla Paylaş'), findsOneWidget);

      // Tap "Apple Cüzdan'a Ekle"
      await tester.tap(find.text('Apple Cüzdan\'a Ekle'));
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog opens
      expect(find.text('Apple Cüzdan\'a Eklendi'), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pump(const Duration(milliseconds: 100));

      // Status changes to Added
      expect(find.text('Apple Cüzdan\'a Eklendi ✓'), findsOneWidget);
    });
  });

  group('3. Event Vibe & Outfit Guide Sheet Widget Tests', () {
    testWidgets('EventVibeGuideSheet recommends Rock grunge style for rock event', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventVibeGuideSheet(event: testRockEvent),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kombin & Etkinlik Rehberi'), findsOneWidget);
      expect(find.text('Grunge & Rock Enerjisi'), findsOneWidget);
      expect(find.textContaining('Deri ceket veya vintage kot ceket'), findsOneWidget);
      expect(find.textContaining('Açık Hava Alanı İpuçları'), findsOneWidget);
      expect(find.text('Konser Çantası Hazırlığı 🎒'), findsOneWidget);
    });

    testWidgets('EventVibeGuideSheet recommends Techno all-black style for techno event', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventVibeGuideSheet(event: testTechnoEvent),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cyber & Techno All-Black'), findsOneWidget);
      expect(find.textContaining('Monokrom siyah minimalist kesimler'), findsOneWidget);
      expect(find.textContaining('Kapalı Salon & Kulüp İpuçları'), findsOneWidget);
    });

    testWidgets('EventVibeGuideSheet checklist checkboxes are interactable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventVibeGuideSheet(event: testFestivalEvent),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final powerbankFinder = find.text('🔋 Taşınabilir Şarj Cihazı (Powerbank)');
      expect(powerbankFinder, findsOneWidget);

      // Tap powerbank checkbox to toggle it
      await tester.tap(powerbankFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('/ 7 Hazır'), findsOneWidget);
    });
  });
}
