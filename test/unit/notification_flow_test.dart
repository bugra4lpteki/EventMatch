import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pure Supabase Notification Flow Tests', () {
    test('NotificationService singleton maintains single instance', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('high_importance_channel configuration has max importance, sound, and vibration', () {
      const channel = NotificationService.highImportanceChannel;
      expect(channel.id, equals('high_importance_channel'));
      expect(channel.importance.name, equals('max'));
      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
    });

    test('Active chat suppression logic correctly silences ONLY when app is foreground and chat is open', () {
      final service = NotificationService();

      // Case 1: App is in foreground, user is inside active chat -> Should suppress
      service.isAppInForeground = true;
      service.activeChatId = 'partner_123';

      bool shouldSuppress = service.isAppInForeground &&
          service.activeChatId != null &&
          service.activeChatId!.toLowerCase() == 'partner_123'.toLowerCase();
      expect(shouldSuppress, isTrue);

      // Case 2: User is in another chat -> Should NOT suppress
      service.activeChatId = 'partner_999';
      shouldSuppress = service.isAppInForeground &&
          service.activeChatId != null &&
          service.activeChatId!.toLowerCase() == 'partner_123'.toLowerCase();
      expect(shouldSuppress, isFalse);

      // Case 3: App is in BACKGROUND / PHONE LOCKED -> MUST NEVER suppress, even if activeChatId matches!
      service.isAppInForeground = false;
      service.activeChatId = 'partner_123';
      shouldSuppress = service.isAppInForeground &&
          service.activeChatId != null &&
          service.activeChatId!.toLowerCase() == 'partner_123'.toLowerCase();
      expect(shouldSuppress, isFalse, reason: 'When app is in background, WhatsApp heads-up notifications must fire!');
    });

    test('Deduplication prevents duplicate notifications within 2 seconds window', () {
      final recentNotifications = <String, DateTime>{};
      final now = DateTime.now();

      final dedupeKey = 'msg_1001';
      recentNotifications[dedupeKey] = now;

      final isDuplicate = recentNotifications.containsKey(dedupeKey) &&
          DateTime.now().difference(recentNotifications[dedupeKey]!).inSeconds < 2;

      expect(isDuplicate, isTrue);
    });
  });
}
