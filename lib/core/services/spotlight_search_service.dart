import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../features/events/models/event_model.dart';

/// iOS CoreSpotlight ve Siri Shortcuts İndeksleme Servisi
/// Kullanıcının görüntülediği veya favorilediği etkinlikleri iOS sistem aramasına ekler.
class SpotlightSearchService {
  static const MethodChannel _channel = MethodChannel('com.eventmatch.app/spotlight');
  static final SpotlightSearchService _instance = SpotlightSearchService._internal();
  factory SpotlightSearchService() => _instance;

  SpotlightSearchService._internal() {
    _initChannel();
  }

  void _initChannel() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSpotlightEventTapped') {
        final eventId = call.arguments as String?;
        if (eventId != null && eventId.isNotEmpty) {
          debugPrint('[Spotlight] Spotlight/Siri üzerinden etkinlik açıldı: $eventId');
          onEventSelectedFromSpotlight?.call(eventId);
        }
      }
    });
  }

  /// Spotlight aramasından bir etkinlik seçildiğinde dinleyecek callback
  static void Function(String eventId)? onEventSelectedFromSpotlight;

  /// Etkinliği iOS Spotlight ve Siri Shortcuts indeksine ekler
  Future<void> indexEvent(EventModel event) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _channel.invokeMethod('indexEvent', {
        'id': event.id,
        'title': event.title,
        'description': '${event.location} • ${event.category}',
        'keywords': [
          event.title,
          event.category,
          event.location,
          'EventMatch',
          'Konser',
          'Festival',
          'Bilet',
        ],
      });
      debugPrint('[Spotlight] İndekslendi: ${event.title}');
    } catch (e) {
      debugPrint('[Spotlight] İndeksleme hatası: $e');
    }
  }

  /// Etkinliği Spotlight indeksinden kaldırır
  Future<void> deindexEvent(String eventId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      await _channel.invokeMethod('deindexEvent', {'id': eventId});
    } catch (e) {
      debugPrint('[Spotlight] İndeks kaldırma hatası: $e');
    }
  }
}
