import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_match/features/events/models/user_model.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  group('Mavi Tik (Verified Badge) Visibility & Privacy Tests', () {
    test('Verified user with showVerifiedBadge=true shows badge (visible)', () {
      final user = UserModel(
        id: 'u1',
        name: 'Ahmet',
        avatarUrl: '',
        isVerified: true,
        showVerifiedBadge: true,
      );

      expect(user.isVerified, isTrue);
      expect(user.showVerifiedBadge, isTrue);
      expect(user.isVerifiedBadgeVisible, isTrue);
    });

    test('Verified user with showVerifiedBadge=false hides badge (hidden by privacy)', () {
      final user = UserModel(
        id: 'u2',
        name: 'Zeynep',
        avatarUrl: '',
        isVerified: true,
        showVerifiedBadge: false,
      );

      expect(user.isVerified, isTrue);
      expect(user.showVerifiedBadge, isFalse);
      expect(user.isVerifiedBadgeVisible, isFalse);
    });

    test('Unverified user never shows verified badge regardless of showVerifiedBadge toggle', () {
      final user = UserModel(
        id: 'u3',
        name: 'Mehmet',
        avatarUrl: '',
        isVerified: false,
        showVerifiedBadge: true,
      );

      expect(user.isVerified, isFalse);
      expect(user.isVerifiedBadgeVisible, isFalse);

      user.showVerifiedBadge = false;
      expect(user.isVerifiedBadgeVisible, isFalse);
    });

    test('UserModel.toMap and fromMap preserves show_verified_badge', () {
      final user = UserModel(
        id: 'u4',
        name: 'Can',
        avatarUrl: '',
        isVerified: true,
        showVerifiedBadge: false,
      );

      final map = user.toMap();
      expect(map['is_verified'], isTrue);
      expect(map['show_verified_badge'], isFalse);

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.isVerified, isTrue);
      expect(reconstructed.showVerifiedBadge, isFalse);
      expect(reconstructed.isVerifiedBadgeVisible, isFalse);
    });

    test('UserModel.fromMap defaults showVerifiedBadge to true when key is omitted', () {
      final map = {
        'id': 'u5',
        'name': 'Elif',
        'is_verified': true,
      };

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.isVerified, isTrue);
      expect(reconstructed.showVerifiedBadge, isTrue);
      expect(reconstructed.isVerifiedBadgeVisible, isTrue);
    });

    test('MockEventService updatePrivacySettings toggles showVerifiedBadge and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MockEventService();

      expect(service.currentUser.showVerifiedBadge, isTrue);

      await service.updatePrivacySettings(showVerifiedBadge: false);
      expect(service.currentUser.showVerifiedBadge, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('show_verified_badge'), isFalse);
      expect(prefs.getBool('${service.currentUser.id}_show_verified_badge'), isFalse);

      await service.updatePrivacySettings(showVerifiedBadge: true);
      expect(service.currentUser.showVerifiedBadge, isTrue);
      expect(prefs.getBool('show_verified_badge'), isTrue);
    });

    test('MockEventService verifyCurrentUserEmail enables isVerified and showVerifiedBadge', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MockEventService();

      service.currentUser.isVerified = false;
      service.currentUser.showVerifiedBadge = false;

      await service.verifyCurrentUserEmail('test@eventmatch.app');

      expect(service.currentUser.isVerified, isTrue);
      expect(service.currentUser.showVerifiedBadge, isTrue);
      expect(service.currentUser.isVerifiedBadgeVisible, isTrue);
      expect(service.currentUser.badges.contains('verified'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_email_verified'), isTrue);
      expect(prefs.getBool('show_verified_badge'), isTrue);
    });
  });
}
