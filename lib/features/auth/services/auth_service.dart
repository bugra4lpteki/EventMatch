import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  bool get isAuthenticated => _supabase.auth.currentSession != null;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  AuthService() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    const webClientId = '1089492303271-usnrteug9r9o2j8cge5t6b7ctk0acvik.apps.googleusercontent.com';
    
    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? webClientId : null,
        serverClientId: kIsWeb ? null : webClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı seçimi iptal etti
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('Google idToken alınamadı.');
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Auth] Google Sign-In error: $e');
      if (e.toString().contains('sign_in_canceled') || e.toString().contains('canceled')) {
        return false;
      }
      throw Exception('Google ile giriş sırasında hata oluştu: $e');
    }
  }

  Future<bool> signInWithApple() async {
    try {
      final res = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'io.supabase.eventmatch://login-callback/',
        authScreenLaunchMode: LaunchMode.platformDefault,
      );
      notifyListeners();
      return res;
    } on AuthException catch (e) {
      debugPrint('Apple OAuth AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Apple OAuth Error: $e');
      throw Exception('Apple ile giriş sırasında hata oluştu: $e');
    }
  }

  Future<String?> login(String emailOrUsername, String password) async {
    try {
      String email = emailOrUsername.trim();
      
      // E-posta formatında değilse kullanıcı adından e-postayı çekmeyi dene
      if (!email.contains('@')) {
        try {
          final res = await _supabase
              .from('users')
              .select('id')
              .eq('username', email)
              .maybeSingle();
          if (res != null) {
            // Eğer username bulunduysa auth tablosundan deneyebiliriz veya kullanıcı doğrudan email girsin
          }
        } catch (_) {}
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null) {
        notifyListeners();
        return null;
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

  Future<String?> updatePassword(String newPassword) async {
    try {
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

  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
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
