import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_match/features/events/services/moderation_service.dart';
import 'package:event_match/features/events/services/spotify_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Timestamp Formatting Tests', () {
    String formatChatTimestamp(DateTime timestamp, DateTime now) {
      final localTs = timestamp.toLocal();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate = DateTime(localTs.year, localTs.month, localTs.day);
      final diffDays = today.difference(msgDate).inDays;

      if (diffDays <= 0) {
        final h = localTs.hour.toString().padLeft(2, '0');
        final m = localTs.minute.toString().padLeft(2, '0');
        return '$h:$m';
      } else if (diffDays == 1) {
        return 'Dün';
      } else if (diffDays > 1 && diffDays < 7) {
        const dayNames = [
          'Pazartesi',
          'Salı',
          'Çarşamba',
          'Perşembe',
          'Cuma',
          'Cumartesi',
          'Pazar',
        ];
        return dayNames[localTs.weekday - 1];
      } else {
        final d = localTs.day.toString().padLeft(2, '0');
        final mo = localTs.month.toString().padLeft(2, '0');
        final y = localTs.year.toString();
        return '$d.$mo.$y';
      }
    }

    test('Today shows HH:mm (e.g. 02:03)', () {
      final now = DateTime(2026, 9, 28, 14, 30);
      final msg = DateTime(2026, 9, 28, 2, 3);
      expect(formatChatTimestamp(msg, now), equals('02:03'));
    });

    test('Yesterday shows Dün', () {
      final now = DateTime(2026, 9, 28, 14, 30);
      final msg = DateTime(2026, 9, 27, 20, 15);
      expect(formatChatTimestamp(msg, now), equals('Dün'));
    });

    test('Within 1 week shows Turkish day name (e.g. Cuma, Perşembe)', () {
      final now = DateTime(2026, 9, 28, 14, 30); // 28 Sept 2026 is Monday
      final msgFriday = DateTime(2026, 9, 25, 12, 0); // 3 days ago = Friday
      expect(formatChatTimestamp(msgFriday, now), equals('Cuma'));

      final msgSaturday = DateTime(2026, 9, 26, 12, 0); // 2 days ago = Saturday
      expect(formatChatTimestamp(msgSaturday, now), equals('Cumartesi'));
    });

    test('Older than 1 week shows long date dd.MM.yyyy (e.g. 12.05.2026)', () {
      final now = DateTime(2026, 9, 28, 14, 30);
      final msgOld = DateTime(2026, 9, 9, 10, 0);
      expect(formatChatTimestamp(msgOld, now), equals('09.09.2026'));

      final msgCustom = DateTime(2026, 5, 12, 18, 0);
      expect(formatChatTimestamp(msgCustom, now), equals('12.05.2026'));
    });
  });

  group('ModerationService Blocked User Name Resolution & Instant Removal', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('blockUser stores displayName and unblockUser removes it instantly', () async {
      final service = ModerationService();
      expect(service.isBlocked('test_user_1'), isFalse);

      await service.blockUser('test_user_1', userName: 'Yusuf Nair');
      expect(service.isBlocked('test_user_1'), isTrue);
      expect(service.getBlockedUserName('test_user_1'), equals('Yusuf Nair'));

      await service.unblockUser('test_user_1');
      expect(service.isBlocked('test_user_1'), isFalse);
      expect(service.getBlockedUserName('test_user_1'), isEmpty);
    });
  });

  group('Spotify Track Preview Resilience', () {
    test('resolveAudioPreview handles cleaned track title and curated tracks', () async {
      final spotify = SpotifyService();
      final preview = await spotify.resolveAudioPreview('Aleyna Tilki', 'Cevapsız Çınlama');
      expect(preview, isNotNull);
      expect(preview, isNotEmpty);
      expect(preview, isNot(contains('soundhelix')));
    });
  });
}
