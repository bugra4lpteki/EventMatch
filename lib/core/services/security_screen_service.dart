import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ekran görüntüsü ve ekran kaydı koruma servisi.
/// Android tarafında `FLAG_SECURE` pencere bayrağını,
/// iOS tarafında ise güvenli katman/ekran korumasını yönetir.
class SecurityScreenService {
  SecurityScreenService._();
  static final SecurityScreenService instance = SecurityScreenService._();

  static const MethodChannel _channel = MethodChannel('com.eventmatch.app/security');
  bool _isSecure = false;
  bool get isSecure => _isSecure;

  /// Ekran görüntüsü ve ekran kaydı almayı engeller.
  /// Android'de `WindowManager.LayoutParams.FLAG_SECURE` bayrağını ayarlar.
  Future<void> enableSecure() async {
    if (kIsWeb) return;
    try {
      _isSecure = true;
      await _channel.invokeMethod('enableSecure');
      debugPrint('[SecurityScreenService] 🛡️ Ekran koruması aktif (FLAG_SECURE)');
    } catch (e) {
      debugPrint('[SecurityScreenService] ⚠️ enableSecure uyarısı: $e');
    }
  }

  /// Ekran korumasını kaldırır.
  Future<void> disableSecure() async {
    if (kIsWeb) return;
    try {
      _isSecure = false;
      await _channel.invokeMethod('disableSecure');
      debugPrint('[SecurityScreenService] 🔓 Ekran koruması devre dışı bırakıldı');
    } catch (e) {
      debugPrint('[SecurityScreenService] ⚠️ disableSecure uyarısı: $e');
    }
  }
}
