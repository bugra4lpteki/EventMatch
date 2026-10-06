import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/features/events/models/user_model.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/mock_match_service.dart';
import 'package:event_match/features/profile/widgets/vip_paywall_sheet.dart';

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

  group('💎 EventMatch VIP Model & Logic Tests', () {
    test('UserModel VIP serialization and active status getters work accurately', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      // Active VIP User
      final activeVipUser = UserModel(
        id: 'vip_user_1',
        name: 'VIP User',
        avatarUrl: 'https://example.com/avatar1.jpg',
        isVip: true,
        vipExpiryDate: futureDate,
      );

      expect(activeVipUser.hasActiveVip, isTrue);

      // Expired VIP User
      final expiredVipUser = UserModel(
        id: 'vip_user_2',
        name: 'Expired VIP',
        avatarUrl: 'https://example.com/avatar2.jpg',
        isVip: true,
        vipExpiryDate: pastDate,
      );

      expect(expiredVipUser.hasActiveVip, isFalse);

      // Non-VIP User
      final regularUser = UserModel(
        id: 'regular_1',
        name: 'Regular User',
        avatarUrl: 'https://example.com/avatar3.jpg',
        isVip: false,
      );

      expect(regularUser.hasActiveVip, isFalse);

      // toMap & fromMap preserves VIP data
      final map = activeVipUser.toMap();
      expect(map['is_vip'], isTrue);
      expect(map['vip_expires_at'], isNotNull);

      final restored = UserModel.fromMap(map);
      expect(restored.isVip, isTrue);
      expect(restored.hasActiveVip, isTrue);
    });

    test('UserModel 1-Hour Radar Boost getters and countdown work accurately', () {
      final boostExpiry = DateTime.now().add(const Duration(minutes: 50));
      final boostedUser = UserModel(
        id: 'boosted_1',
        name: 'Boosted User',
        avatarUrl: 'https://example.com/avatar_boost.jpg',
        boostExpiryDate: boostExpiry,
      );

      expect(boostedUser.isBoosted, isTrue);
      expect(boostedUser.boostRemainingTime, isNotNull);
      expect(boostedUser.boostRemainingTime!.inMinutes, greaterThanOrEqualTo(49));

      // Expired boost
      final expiredBoostUser = UserModel(
        id: 'expired_boost_1',
        name: 'Expired Boost',
        avatarUrl: 'https://example.com/avatar_exp.jpg',
        boostExpiryDate: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(expiredBoostUser.isBoosted, isFalse);
    });

    test('MockEventService activateVip, cancelVip and activateBoost work accurately', () async {
      final service = MockEventService();

      // Activate VIP for 30 days
      await service.activateVip(days: 30);
      expect(service.currentUser.isVip, isTrue);
      expect(service.currentUser.hasActiveVip, isTrue);
      expect(service.currentUser.vipExpiryDate, isNotNull);

      // Activate 1-hour boost
      await service.activateBoost(hours: 1);
      expect(service.currentUser.isBoosted, isTrue);
      expect(service.currentUser.boostRemainingTime?.inMinutes, greaterThanOrEqualTo(59));

      // Cancel VIP
      await service.cancelVip();
      expect(service.currentUser.isVip, isFalse);
      expect(service.currentUser.hasActiveVip, isFalse);
    });

    test('MockMatchService undoSwipe restores swiped user to deck for VIP undo', () async {
      final eventService = MockEventService();
      final matchService = MockMatchService(eventService);
      // Wait for any async init to finish
      await Future.delayed(const Duration(milliseconds: 300));

      final testUser = UserModel(
        id: 'test_swiped_user_99',
        name: 'Swiped Candidate',
        avatarUrl: 'https://example.com/swiped.jpg',
      );

      // Swipe left
      await matchService.swipeLeft(testUser);
      final potentialAfterSwipe = matchService.getPotentialMatches();
      expect(potentialAfterSwipe.any((u) => u.id == testUser.id), isFalse);

      // VIP Undo Swipe
      await matchService.undoSwipe(testUser);
      final potentialAfterUndo = matchService.getPotentialMatches();
      expect(potentialAfterUndo.any((u) => u.id == testUser.id), isTrue);
      expect(potentialAfterUndo.first.id, equals(testUser.id));
    });

    test('VipFeature enum contains all 4 requested core monetization benefits', () {
      expect(VipFeature.values.contains(VipFeature.seeLikes), isTrue);
      expect(VipFeature.values.contains(VipFeature.undoSwipe), isTrue);
      expect(VipFeature.values.contains(VipFeature.venueBadge), isTrue);
      expect(VipFeature.values.contains(VipFeature.mapBoost), isTrue);
    });
  });
}
