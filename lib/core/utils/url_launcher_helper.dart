import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  /// Bilet linklerini, harita konumlarını veya sosyal medya linklerini güvenli şekilde açar.
  static Future<bool> launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return false;

    String cleanUrl = urlString.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null) {
      debugPrint('Geçersiz URL: $cleanUrl');
      return false;
    }

    try {
      // 1. Öncelikli olarak harici tarayıcıda / uygulamada açmayı dene
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('LaunchMode.externalApplication denemesi başarısız: $e');
    }

    try {
      // 2. Varsayılan platform modu ile yedek açma denemesi
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('LaunchMode.platformDefault denemesi başarısız: $e');
    }

    return false;
  }
}
