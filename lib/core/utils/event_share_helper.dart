import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/events/models/event_model.dart';
import '../services/weather_service.dart';

class EventShareHelper {
  /// Etkinliği zengin görsel afişi ve WhatsApp / sosyal medya uyumlu formatlı mesajıyla paylaşır
  static Future<void> shareEvent({
    required BuildContext context,
    required EventModel event,
    EventWeatherData? weather,
  }) async {
    final formattedDate =
        '${event.dateTime.day} ${_getTurkishMonth(event.dateTime.month)} ${event.dateTime.year} • ${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}';

    final weatherLine = weather != null
        ? '🌤️ *Mekan Havası:* ${weather.temperature.round()}°C • ${weather.conditionText}\n'
        : '';

    final ticketUrl = event.effectiveTicketUrl.isNotEmpty
        ? event.effectiveTicketUrl
        : 'https://eventmatch.app/events/${event.id}';

    // WhatsApp ve sosyal medya için kalın başlıklar, emojiler ve ayraçlarla zengin metin
    final richCaption = '''
✨ *EVENTMATCH ETKİNLİK DAVETİ* ✨
━━━━━━━━━━━━━━━━━━━━━
🎟️ *${event.title.toUpperCase()}*
🎭 *Kategori:* ${event.category}
🗓️ *Tarih:* $formattedDate
📍 *Mekan:* ${event.location}
$weatherLine━━━━━━━━━━━━━━━━━━━━━
💬 *"Benimle bu etkinliğe gelmek ister misin? Birlikte gidelim!"* 🔥

🎫 *Bilet & Detaylar:*
$ticketUrl
━━━━━━━━━━━━━━━━━━━━━
⚡ _EventMatch • Canlı Etkinlik ve Festival Topluluğu_
'''.trim();

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 300, 300);

    // 1. Etkinlik görselini indirip WhatsApp'a afişli olarak paylaşmayı dene
    File? tempImageFile;
    if (event.imageUrl.isNotEmpty && event.imageUrl.startsWith('http')) {
      try {
        final uri = Uri.parse(event.imageUrl);
        final response = await http.get(uri).timeout(const Duration(milliseconds: 2500));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/event_${event.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.jpg');
          await file.writeAsBytes(response.bodyBytes);
          tempImageFile = file;
        }
      } catch (e) {
        debugPrint('[EventShareHelper] Image fetch skipped: $e');
      }
    }

    try {
      if (tempImageFile != null && await tempImageFile.exists()) {
        await Share.shareXFiles(
          [XFile(tempImageFile.path)],
          text: richCaption,
          subject: 'EventMatch: ${event.title}',
          sharePositionOrigin: origin,
        );
      } else {
        await Share.share(
          richCaption,
          subject: 'EventMatch: ${event.title}',
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      debugPrint('[EventShareHelper] Share error: $e');
      // Son çare fallback
      try {
        await Share.share(richCaption, sharePositionOrigin: origin);
      } catch (_) {}
    }
  }

  /// Kombin ve Vibe rehberini zengin kart formatında paylaşır
  static Future<void> shareVibeGuide({
    required BuildContext context,
    required EventModel event,
    required Map<String, dynamic> rec,
    required bool isOutdoor,
    EventWeatherData? weather,
  }) async {
    final weatherLine = weather != null
        ? '🌤️ *Canlı Hava:* ${weather.temperature.round()}°C • ${weather.conditionText}\n'
        : '';

    final richText = '''
✨ *${event.title.toUpperCase()} KOMBİN & REHBER* ✨
━━━━━━━━━━━━━━━━━━━━━
🎭 *Tarz & Enerji:* ${rec['vibeTitle']} ${rec['vibeEmoji']}
👕 *Kıyafet Seçimi:* ${rec['outfitText']}
👟 *Ayakkabı:* ${rec['shoesText']}
🏛️ *Mekan Tipi:* ${isOutdoor ? "Açık Hava Alanı 🌳" : "Kapalı Salon / Kulüp 🏛️"}
$weatherLine━━━━━━━━━━━━━━━━━━━━━
💬 *"EventMatch ile etkinlikte buluşalım!"* 🎉
'''.trim();

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(0, 0, 300, 300);

    try {
      await Share.share(
        richText,
        subject: 'EventMatch: ${event.title} Kombin Rehberi',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      debugPrint('[EventShareHelper] Vibe share error: $e');
    }
  }

  static String _getTurkishMonth(int month) {
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return (month >= 1 && month <= 12) ? months[month] : '';
  }
}
