import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  bool _showRestoredBanner = false;
  bool get showRestoredBanner => _showRestoredBanner;

  Timer? _restoredTimer;

  ConnectivityService._internal() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('[ConnectivityService] Init error: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool newIsOnline = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

    if (_isOnline != newIsOnline) {
      if (newIsOnline && !_isOnline) {
        // Çevrimdışıyken yeniden bağlandı: 3 saniye boyunca yeşil "Bağlantı kuruldu" göster
        _showRestoredBanner = true;
        _restoredTimer?.cancel();
        _restoredTimer = Timer(const Duration(seconds: 3), () {
          _showRestoredBanner = false;
          notifyListeners();
        });
      } else {
        _showRestoredBanner = false;
        _restoredTimer?.cancel();
      }

      _isOnline = newIsOnline;
      notifyListeners();
      debugPrint('[ConnectivityService] 🌐 Bağlantı durumu: ${_isOnline ? "ÇEVRİMİÇİ" : "ÇEVRİMDAŞI"}');
    }
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
