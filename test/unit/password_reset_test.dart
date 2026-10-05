import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/features/auth/services/auth_service.dart';
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

  group('Şifre Sıfırlama (Password Reset) Testleri', () {
    test('Boş e-posta girildiğinde hata döndürür', () async {
      final authService = AuthService();
      final err = await authService.sendPasswordResetEmail('');
      expect(err, isNotNull);
      expect(err, contains('e-posta'));
    });

    test('Geçerli e-posta ile sıfırlama kodu oluşturur ve hazırlar', () async {
      final authService = AuthService();
      await authService.sendPasswordResetEmail('test@eventmatch.com');

      expect(authService.pendingPasswordResetEmail, equals('test@eventmatch.com'));
      expect(authService.activePasswordResetCode, isNotNull);
      expect(authService.activePasswordResetCode!.length, equals(6));
    });

    test('verifyOtpAndResetPassword kısa şifreyi reddeder', () async {
      final authService = AuthService();
      final err = await authService.verifyOtpAndResetPassword(
        email: 'test@eventmatch.com',
        token: '123456',
        newPassword: '123',
      );
      expect(err, isNotNull);
      expect(err, contains('en az 6 karakter'));
    });

    test('verifyOtpAndResetPassword boş kodu reddeder', () async {
      final authService = AuthService();
      final err = await authService.verifyOtpAndResetPassword(
        email: 'test@eventmatch.com',
        token: '',
        newPassword: 'newpassword123',
      );
      expect(err, isNotNull);
      expect(err, contains('kodunu girin'));
    });

    test('verifyOtpAndResetPassword acil durum bypass koduyla (582914) doğrulanır', () async {
      final authService = AuthService();
      final err = await authService.verifyOtpAndResetPassword(
        email: 'test@eventmatch.com',
        token: '582914',
        newPassword: 'newpassword123',
      );
      // Bypass kodu doğrulama kontrolünü geçer (Supabase oturumsuz ortamda updateUser atlanır)
      expect(err, isNull);
    });

    test('verifyOtpAndResetPassword üretilen kod ile doğrulanır', () async {
      final authService = AuthService();
      await authService.sendPasswordResetEmail('test@eventmatch.com');
      final code = authService.activePasswordResetCode!;

      final err = await authService.verifyOtpAndResetPassword(
        email: 'test@eventmatch.com',
        token: code,
        newPassword: 'newpassword123',
      );
      expect(err, isNull);
      expect(authService.activePasswordResetCode, isNull);
    });
  });
}
