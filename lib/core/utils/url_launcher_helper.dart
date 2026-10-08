import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  /// Bilet linklerini, harita konumlarını veya sosyal medya linklerini güvenli şekilde açar.
  static Future<bool> launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return false;

    String cleanUrl = urlString.trim();
    final isSpecialScheme = cleanUrl.startsWith('mailto:') ||
        cleanUrl.startsWith('tel:') ||
        cleanUrl.startsWith('sms:') ||
        cleanUrl.startsWith('calshow:');

    if (!isSpecialScheme && !cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null) {
      debugPrint('Geçersiz URL: $cleanUrl');
      return false;
    }

    if (isSpecialScheme) {
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        debugPrint('Özel şema ($cleanUrl) açma hatası: $e');
        return false;
      }
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

  /// Platforma uygun navigasyon / harita yol tarifi URL'i üretir.
  /// iOS üzerinde yerel Apple Haritalar (Apple Maps), diğer platformlarda Google Maps açar.
  static String getDirectionsUrl({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    final hasCoord = latitude != null && longitude != null;
    final isIosDevice = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isIosDevice) {
      if (hasCoord) {
        if (address != null && address.trim().isNotEmpty) {
          final encodedAddr = Uri.encodeComponent(address.trim());
          return 'https://maps.apple.com/?daddr=$encodedAddr&ll=$latitude,$longitude&dirflg=d';
        }
        return 'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d';
      } else if (address != null && address.trim().isNotEmpty) {
        return 'https://maps.apple.com/?daddr=${Uri.encodeComponent(address.trim())}&dirflg=d';
      }
      return 'https://maps.apple.com/';
    } else {
      if (hasCoord) {
        return 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
      } else if (address != null && address.trim().isNotEmpty) {
        return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address.trim())}';
      }
      return 'https://www.google.com/maps';
    }
  }

  /// Platforma uygun harita yol tarifini doğrudan açar.
  static Future<bool> openDirections({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final url = getDirectionsUrl(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    return await launchURL(url);
  }
}
