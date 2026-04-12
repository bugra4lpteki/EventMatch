import 'package:flutter/material.dart';

class MockAuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _currentUserEmail;
  String? get currentUserEmail => _currentUserEmail;

  Future<bool> login(String email, String password) async {
    // Simüle edilmiş bekleme süresi
    await Future.delayed(const Duration(seconds: 2));
    
    if (email.isNotEmpty && password.length >= 6) {
      _isAuthenticated = true;
      _currentUserEmail = email;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> register(String email, String password, DateTime dob) async {
    // Simüle edilmiş bekleme süresi
    await Future.delayed(const Duration(seconds: 2));
    
    if (email.isNotEmpty && password.length >= 6) {
      _isAuthenticated = true;
      _currentUserEmail = email;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _isAuthenticated = false;
    _currentUserEmail = null;
    notifyListeners();
  }
}
