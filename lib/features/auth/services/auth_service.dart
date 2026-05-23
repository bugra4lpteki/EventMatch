import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool get isAuthenticated => _supabase.auth.currentSession != null;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
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
      return e.message;
    } catch (e) {
      debugPrint('Login Error: $e');
      return 'Giriş sırasında bir hata oluştu.';
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
      
      return response.user != null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('unique') || e.message.toLowerCase().contains('duplicate')) {
        throw Exception('Bu kullanıcı adı alınmış');
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Register Error: $e');
      if (e.toString().toLowerCase().contains('unique') || e.toString().toLowerCase().contains('duplicate')) {
        throw Exception('Bu kullanıcı adı alınmış');
      }
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
