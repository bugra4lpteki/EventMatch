import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/notification_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isTwoFactorPending = false;
  bool get isTwoFactorPending => _isTwoFactorPending;

  bool _isDemoUser = false;
  bool get isDemoUser => _isDemoUser;

  bool get isAuthenticated => (_supabase.auth.currentSession != null || _isDemoUser) && !_isTwoFactorPending;
  String? get currentUserEmail => _isDemoUser ? 'demo@eventmatch.app' : _supabase.auth.currentUser?.email;
  String? get currentUserId => _isDemoUser ? 'dae11b96-8e19-490a-b0ae-a002bd7965be' : _supabase.auth.currentUser?.id;

  String? _activeTwoFactorCode;
  DateTime? _activeTwoFactorExpiry;
  String? _pendingTwoFactorEmail;

  String? get pendingTwoFactorEmail => _pendingTwoFactorEmail;
  String? get activeTwoFactorCode => _activeTwoFactorCode;

  AuthService() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (!_isTwoFactorPending) {
          _activeTwoFactorCode = null;
          _activeTwoFactorExpiry = null;
          _pendingTwoFactorEmail = null;
        }
      }
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    try {
      final res = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.eventmatch://login-callback/',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      notifyListeners();
      return res;
    } on AuthException catch (e) {
      debugPrint('[Auth] Google OAuth AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('provider is not enabled') || msg.contains('unsupported provider')) {
        throw Exception('Google ile Giriş henüz Supabase üzerinde etkinleştirilmedi.');
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[Auth] Google Sign-In error: $e');
      final str = e.toString().toLowerCase();
      if (str.contains('sign_in_canceled') || str.contains('canceled') || str.contains('cancelled')) {
        return false;
      }
      if (str.contains('network_error') || str.contains('socketexception') || str.contains('connection failed')) {
        throw Exception('İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edin.');
      }
      throw Exception('Google ile giriş sırasında hata oluştu: $e');
    }
  }

  Future<bool> signInWithApple() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        try {
          final rawNonce = _supabase.auth.generateRawNonce();
          final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

          final credential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            nonce: hashedNonce,
          );

          final idToken = credential.identityToken;
          if (idToken != null) {
            final res = await _supabase.auth.signInWithIdToken(
              provider: OAuthProvider.apple,
              idToken: idToken,
              nonce: rawNonce,
            );
            notifyListeners();
            return res.user != null;
          }
        } catch (nativeErr) {
          debugPrint('Native Apple Sign In error/fallback: $nativeErr');
          final str = nativeErr.toString().toLowerCase();
          if (str.contains('canceled') || str.contains('cancelled') || str.contains('1001')) {
            return false;
          }
          // If native failed, fallback to OAuth flow below
        }
      }

      final res = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'io.supabase.eventmatch://login-callback/',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      notifyListeners();
      return res;
    } on AuthException catch (e) {
      debugPrint('Apple OAuth AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('provider is not enabled') || msg.contains('unsupported provider')) {
        throw Exception('Apple ile Giriş henüz Supabase üzerinde etkinleştirilmedi. (Supabase -> Authentication -> Providers -> Apple)');
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Apple OAuth Error: $e');
      final str = e.toString().toLowerCase();
      if (str.contains('canceled') || str.contains('cancelled')) {
        return false;
      }
      if (str.contains('provider is not enabled') || str.contains('apple')) {
        throw Exception('Apple ile Giriş için Supabase Apple OAuth ve Apple Developer hesap yapılandırması gereklidir.');
      }
      throw Exception('Apple ile giriş sırasında hata oluştu: $e');
    }
  }

  Future<String?> login(String emailOrUsername, String password) async {
    try {
      String email = emailOrUsername.trim();
      final isDemoCredentials = (email.toLowerCase() == 'demo@eventmatch.app' ||
                                 email.toLowerCase() == 'demo' ||
                                 email.toLowerCase() == 'appledemo') &&
                                password == 'EventMatch2026!';

      if (isDemoCredentials) {
        email = 'demo@eventmatch.app';
      }

      // E-posta formatında değilse kullanıcı adından e-postayı çekmeyi dene
      if (!email.contains('@')) {
        if (email.toLowerCase() == 'demo' || email.toLowerCase() == 'appledemo') {
          email = 'demo@eventmatch.app';
        } else {
          try {
            final cleanUser = email.replaceAll('@', '').toLowerCase();
            final res = await _supabase
                .from('users')
                .select('id, email')
                .ilike('username', cleanUser)
                .maybeSingle();

            if (res != null && res['email'] != null && res['email'].toString().isNotEmpty) {
              email = res['email'].toString().trim();
            } else {
              return '@$cleanUser kullanıcı adına ait hesap bulunamadı veya e-posta eşleşmesi yok. Lütfen e-posta adresinizle giriş yapın.';
            }
          } catch (e) {
            debugPrint('Username to email resolve hatası: $e');
          }
        }
      }

      try {
        final response = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.session != null) {
          final uid = response.user?.id;
          final uEmail = response.user?.email ?? email;

          // Apple Demo hesabı için 2FA kontrolünü atla (İncelemecinin takılmasını önler)
          final is2fa = isDemoCredentials ? false : await isTwoFactorEnabled(userId: uid, email: uEmail);
          if (is2fa) {
            _isTwoFactorPending = true;
            _pendingTwoFactorEmail = uEmail;
            
            // 2FA tamamlanmadan anasayfaya sızmayı engellemek için geçici oturumu temizle
            await _supabase.auth.signOut();
            _isTwoFactorPending = true;
            _pendingTwoFactorEmail = uEmail;

            final sendErr = await sendTwoFactorCode(email: uEmail);
            if (sendErr != null) {
              _isTwoFactorPending = false;
              _pendingTwoFactorEmail = null;
              notifyListeners();
              return sendErr;
            }
            notifyListeners();
            return '2FA_REQUIRED';
          }

          _isTwoFactorPending = false;
          _isDemoUser = isDemoCredentials;
          if (uid != null) {
            NotificationService().syncUserWithOneSignal(uid);
          }
          notifyListeners();
          return null;
        }
      } catch (e) {
        if (isDemoCredentials) {
          debugPrint('[Auth] Demo account fallback active for Apple Reviewer: $e');
          _isDemoUser = true;
          _isTwoFactorPending = false;
          notifyListeners();
          return null;
        }
        rethrow;
      }
      return 'Oturum başlatılamadı.';
    } on AuthException catch (e) {
      debugPrint('Login AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Kullanıcı veya şifre hatalı. Yeni veritabanında hesabınız yoksa önce "Aramıza Katıl" sayfasından kayıt olmalısınız.';
      }
      if (msg.contains('email not confirmed')) {
        return 'E-posta onaylanmamış. Supabase Authentication -> Providers -> Email ayarlarından "Confirm email" kapatılabilir.';
      }
      return e.message;
    } catch (e) {
      debugPrint('Login Error: $e');
      return 'Giriş sırasında hata oluştu: $e';
    }
  }

  Future<bool> isUsernameTaken(String username, {String? excludeUserId}) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return false;
    try {
      var query = _supabase.from('users').select('id').ilike('username', clean);
      if (excludeUserId != null && excludeUserId.isNotEmpty) {
        query = query.neq('id', excludeUserId);
      }
      final res = await query.maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('Auth isUsernameTaken error: $e');
      return false;
    }
  }

  Future<bool> register(String name, String username, String email, String password, DateTime birthDate) async {
    try {
      final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
      if (await isUsernameTaken(cleanUsername)) {
        throw Exception('Bu kullanıcı adı zaten alınmış. Lütfen başka bir kullanıcı adı seçin.');
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'username': cleanUsername,
          'birth_date': birthDate.toIso8601String().split('T')[0],
        }, 
      );
      
      if (response.user != null) {
        if (response.session == null) {
          try {
            await _supabase.auth.signInWithPassword(email: email, password: password);
          } catch (_) {}
        }
        return true;
      }
      return false;
    } on AuthException catch (e) {
      debugPrint('AuthException register error: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('unique') || msg.contains('duplicate') || msg.contains('already registered') || msg.contains('already exists')) {
        throw Exception('Bu e-posta veya kullanıcı adı zaten kullanımda');
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Register Error: $e');
      throw Exception('Kayıt başarısız: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      final cleanEmail = email.trim();
      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: kIsWeb ? null : 'io.supabase.eventmatch://login-callback/',
      );
      return null;
    } on AuthException catch (e) {
      debugPrint('Reset password AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') || msg.contains('too many requests')) {
        return 'Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.';
      }
      return e.message;
    } catch (e) {
      debugPrint('Reset password Error: $e');
      return 'Şifre sıfırlama e-postası gönderilemedi: $e';
    }
  }

  Future<String?> verifyOtpAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final cleanEmail = email.trim();
      final cleanToken = token.trim();
      
      final response = await _supabase.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.recovery,
      );

      if (response.session == null && response.user == null) {
        return 'Kurtarma kodu geçersiz veya süresi dolmuş.';
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      debugPrint('Verify OTP AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('expired')) {
        return 'Girdiğiniz kod geçersiz veya süresi dolmuş.';
      }
      return e.message;
    } catch (e) {
      debugPrint('Verify OTP Error: $e');
      return 'Şifre güncellenirken hata oluştu: $e';
    }
  }

  Future<String?> updatePassword(String newPassword, {String? currentPassword}) async {
    try {
      final email = currentUserEmail;
      if (email != null && currentPassword != null && currentPassword.isNotEmpty) {
        // Re-authenticate user to confirm current password
        try {
          await _supabase.auth.signInWithPassword(email: email, password: currentPassword);
        } on AuthException catch (e) {
          return 'Mevcut şifreniz hatalı: ${e.message}';
        }
      }

      if (_supabase.auth.currentSession == null) {
        // Mock / Offline user session fallback
        return null;
      }
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Şifre güncellenirken hata oluştu: $e';
    }
  }

  Future<bool> isTwoFactorEnabled({String? userId, String? email}) async {
    try {
      final uid = userId ?? currentUserId;
      final uEmail = email ?? currentUserEmail;
      
      // 1. Supabase 'users' tablosundan kontrol et
      if (uid != null && uid.isNotEmpty) {
        final res = await _supabase
            .from('users')
            .select('two_factor_enabled')
            .eq('id', uid)
            .maybeSingle();
        if (res != null && res['two_factor_enabled'] != null) {
          final isEnabled = res['two_factor_enabled'] == true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('security_2fa_enabled', isEnabled);
          if (uEmail != null) {
            await prefs.setBool('security_2fa_enabled_${uEmail.toLowerCase()}', isEnabled);
          }
          return isEnabled;
        }
      }
    } catch (e) {
      debugPrint('[Auth] isTwoFactorEnabled query error: $e');
    }

    // 2. Yerel SharedPreferences yedek kontrolü
    try {
      final prefs = await SharedPreferences.getInstance();
      final uEmail = email ?? currentUserEmail;
      if (uEmail != null && uEmail.isNotEmpty) {
        final emailPref = prefs.getBool('security_2fa_enabled_${uEmail.toLowerCase()}');
        if (emailPref != null) return emailPref;
      }
      final uid = userId ?? currentUserId;
      if (uid != null && uid.isNotEmpty) {
        final idPref = prefs.getBool('security_2fa_enabled_$uid');
        if (idPref != null) return idPref;
      }
      return prefs.getBool('security_2fa_enabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setTwoFactorEnabled(bool enabled, {String? email}) async {
    final uid = currentUserId;
    final uEmail = (email ?? currentUserEmail)?.toLowerCase().trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_2fa_enabled', enabled);
      if (uEmail != null && uEmail.isNotEmpty) {
        await prefs.setBool('security_2fa_enabled_$uEmail', enabled);
      }
      if (uid != null && uid.isNotEmpty) {
        await prefs.setBool('security_2fa_enabled_$uid', enabled);
      }
    } catch (e) {
      debugPrint('[Auth] SharedPreferences 2FA error: $e');
    }

    if (uid != null && uid.isNotEmpty) {
      try {
        await _supabase.from('users').update({
          'two_factor_enabled': enabled,
        }).eq('id', uid);
      } catch (e) {
        debugPrint('[Auth] Supabase two_factor_enabled update error: $e');
      }
    }
    notifyListeners();
  }

  Future<String?> sendTwoFactorCode({required String email}) async {
    final cleanEmail = email.trim();
    _pendingTwoFactorEmail = cleanEmail;
    _activeTwoFactorExpiry = DateTime.now().add(const Duration(minutes: 5));

    try {
      debugPrint('[Auth] 🔐 2FA Güvenlik Kodu $cleanEmail e-posta adresine gönderiliyor...');
      await _supabase.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
      );
      debugPrint('[Auth] ✅ 2FA Güvenlik Kodu e-posta olarak gönderildi: $cleanEmail');
      return null;
    } on AuthException catch (e) {
      debugPrint('[Auth] 2FA signInWithOtp AuthException: ${e.message}');
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') || msg.contains('too many requests')) {
        return 'Çok fazla kod talep edildi. Lütfen birkaç dakika sonra tekrar deneyin.';
      }
      return e.message;
    } catch (e) {
      debugPrint('[Auth] 2FA signInWithOtp Error: $e');
      return 'Güvenlik kodu e-postanıza gönderilemedi: $e';
    }
  }

  Future<bool> verifyTwoFactorCode(String inputCode) async {
    final cleanInput = inputCode.trim().replaceAll(' ', '');
    final email = _pendingTwoFactorEmail ?? currentUserEmail;
    if (email == null || email.isEmpty) return false;

    // Apple Reviewer / Acil Test Bypass Kodu
    if (cleanInput == '582914') {
      _isTwoFactorPending = false;
      _pendingTwoFactorEmail = null;
      notifyListeners();
      return true;
    }

    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: cleanInput,
        type: OtpType.email,
      );

      if (response.session != null || response.user != null) {
        _isTwoFactorPending = false;
        _pendingTwoFactorEmail = null;
        final uid = response.user?.id ?? currentUserId;
        if (uid != null) {
          NotificationService().syncUserWithOneSignal(uid);
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[Auth] 2FA verifyOTP Error: $e');
    }
    return false;
  }

  Future<void> cancelTwoFactor() async {
    _isTwoFactorPending = false;
    _activeTwoFactorCode = null;
    _activeTwoFactorExpiry = null;
    _pendingTwoFactorEmail = null;
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    _isDemoUser = false;
    _isTwoFactorPending = false;
    _activeTwoFactorCode = null;
    _activeTwoFactorExpiry = null;
    _pendingTwoFactorEmail = null;
    await _supabase.auth.signOut();
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      final userId = currentUserId;
      if (userId != null) {
        try {
          await _supabase.from('users').delete().eq('id', userId);
        } catch (_) {}
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      await _supabase.auth.signOut();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete Account Error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
