import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<bool> register(String name, String username, String email, String password, DateTime birthDate) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'username': username,
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

  Future<void> logout() async {
    await _supabase.auth.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
