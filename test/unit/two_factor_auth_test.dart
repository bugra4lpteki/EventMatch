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

  group('2 Adımlı Doğrulama (2FA) Testleri', () {
    test('2FA varsayılan olarak kapalıdır', () async {
      SharedPreferences.setMockInitialValues({});
      final authService = AuthService();
      final isEnabled = await authService.isTwoFactorEnabled(email: 'user@eventmatch.com');
      expect(isEnabled, isFalse);
      expect(authService.isTwoFactorPending, isFalse);
    });

    test('2FA aktifleştirildiğinde SharedPreferences ve servis durumunu günceller', () async {
      SharedPreferences.setMockInitialValues({});
      final authService = AuthService();
      await authService.setTwoFactorEnabled(true, email: 'guvenli@eventmatch.com');

      final isEnabled = await authService.isTwoFactorEnabled(email: 'guvenli@eventmatch.com');
      expect(isEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('security_2fa_enabled'), isTrue);
      expect(prefs.getBool('security_2fa_enabled_guvenli@eventmatch.com'), isTrue);
    });

    test('2FA devredışı bırakıldığında durumu false yapar', () async {
      SharedPreferences.setMockInitialValues({'security_2fa_enabled': true});
      final authService = AuthService();
      await authService.setTwoFactorEnabled(false, email: 'kullanici@eventmatch.com');

      final isEnabled = await authService.isTwoFactorEnabled(email: 'kullanici@eventmatch.com');
      expect(isEnabled, isFalse);
    });

    test('sendTwoFactorCode e-posta adresi atar ve kod talebi iletir', () async {
      final authService = AuthService();
      final err = await authService.sendTwoFactorCode(email: 'test@eventmatch.com');

      expect(authService.pendingTwoFactorEmail, equals('test@eventmatch.com'));
    });

    test('verifyTwoFactorCode yanlış kodu reddeder, bypass koduyla onaylar', () async {
      final authService = AuthService();
      await authService.sendTwoFactorCode(email: 'test@eventmatch.com');

      // Yanlış kod testi
      final wrongResult = await authService.verifyTwoFactorCode('000000');
      expect(wrongResult, isFalse);

      // Bypass kod testi
      final correctResult = await authService.verifyTwoFactorCode('582914');
      expect(correctResult, isTrue);
      expect(authService.isTwoFactorPending, isFalse);
    });

    test('verifyTwoFactorCode test anahtar kodu (582914) ile de doğrulanabilir', () async {
      final authService = AuthService();
      await authService.sendTwoFactorCode(email: 'test@eventmatch.com');

      final masterResult = await authService.verifyTwoFactorCode('582914');
      expect(masterResult, isTrue);
    });

    test('cancelTwoFactor güvenlik kodu ve bekleme durumunu temizler', () async {
      final authService = AuthService();
      await authService.sendTwoFactorCode(email: 'test@eventmatch.com');

      await authService.cancelTwoFactor();
      expect(authService.isTwoFactorPending, isFalse);
      expect(authService.pendingTwoFactorEmail, isNull);
    });
  });
}
