import 'package:flutter_test/flutter_test.dart';

class AuthValidator {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-posta adresi boş bırakılamaz.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Geçerli bir e-posta adresi giriniz.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre boş bırakılamaz.';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    return null;
  }
}

void main() {
  group('Auth Validation Tests', () {
    test('Email validator flags empty or invalid emails correctly', () {
      expect(AuthValidator.validateEmail(''), equals('E-posta adresi boş bırakılamaz.'));
      expect(AuthValidator.validateEmail('invalid_email'), equals('Geçerli bir e-posta adresi giriniz.'));
      expect(AuthValidator.validateEmail('test@eventmatch.com'), isNull);
    });

    test('Password validator enforces 6 character minimum', () {
      expect(AuthValidator.validatePassword(''), equals('Şifre boş bırakılamaz.'));
      expect(AuthValidator.validatePassword('12345'), equals('Şifre en az 6 karakter olmalıdır.'));
      expect(AuthValidator.validatePassword('123456'), isNull);
    });
  });
}
