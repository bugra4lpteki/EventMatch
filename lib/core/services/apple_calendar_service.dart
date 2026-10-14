import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../features/events/models/event_model.dart';

/// iOS üzerinde Apple Takvim native EventKit modalını (EKEventEditViewController)
/// açarak kullanıcının etkinliği doğrudan Apple Takvim'e eklemesini sağlayan servis.
class AppleCalendarService {
  static const MethodChannel _channel = MethodChannel('com.eventmatch.app/calendar');

  /// iOS üzerinde Apple Takvim düzenleme penceresini açar.
  /// Android veya diğer platformlarda `false` döner.
  static Future<bool> addEventToCalendar(EventModel event) async {
    if (!kIsWeb && !Platform.isIOS) {
      return false;
    }

    final startUtc = event.dateTime.toUtc();
    final endUtc = startUtc.add(const Duration(hours: 3));

    String cleanDesc = event.description.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    if (cleanDesc.length > 500) {
      cleanDesc = '${cleanDesc.substring(0, 500)}...';
    }
    cleanDesc = '$cleanDesc\n\nEventMatch: ${event.title}';

    try {
      final bool? success = await _channel.invokeMethod<bool>('addEvent', {
        'title': event.title.trim(),
        'description': cleanDesc,
        'notes': cleanDesc,
        'location': event.location.trim(),
        'startDate': startUtc.millisecondsSinceEpoch,
        'endDate': endUtc.millisecondsSinceEpoch,
        'url': 'https://eventmatch.app',
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[AppleCalendarService] PlatformException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AppleCalendarService] Error: $e');
      rethrow;
    }
  }
}
