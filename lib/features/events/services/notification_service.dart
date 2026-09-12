import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/event_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        iOS: initializationSettingsIOS,
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(initializationSettings);

      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestExactAlarmsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init hatası: $e');
    }
  }

  static Future<bool> isReminderSet(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('event_reminder_$eventId') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleReminder(EventModel event) async {
    final currentlySet = await isReminderSet(event.id);
    if (currentlySet) {
      await cancelEventReminders(event);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('event_reminder_${event.id}', false);
      } catch (_) {}
      return false;
    } else {
      await scheduleEventReminders(event);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('event_reminder_${event.id}', true);
      } catch (_) {}
      return true;
    }
  }

  static Future<void> cancelEventReminders(EventModel event) async {
    await initialize();
    final baseId = event.id.hashCode.abs();
    try {
      await _notificationsPlugin.cancel(baseId);
      await _notificationsPlugin.cancel(baseId + 1);
      await _notificationsPlugin.cancel(baseId + 2);
      await _notificationsPlugin.cancel(baseId + 3);
      await _notificationsPlugin.cancel(baseId + 4);
    } catch (e) {
      debugPrint('Hatırlatıcı iptal hatası: $e');
    }
  }

  static Future<void> showRadarNotification(String title, String body) async {
    await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'radar_channel',
      'Radar Notifications',
      channelDescription: 'Etkinlik eşleşme radar bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }

  static Future<void> scheduleEventReminders(EventModel event) async {
    await initialize();

    // Ensure permissions
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_reminder_channel',
      'Event Reminders',
      channelDescription: 'Etkinlik hatırlatıcı bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final eventTime = event.dateTime;
    final now = DateTime.now();
    final baseId = event.id.hashCode.abs();

    // 0. Anında onay bildirimi (Kullanıcı basar basmaz anında ekrana düşen push bildirim)
    try {
      await _notificationsPlugin.show(
        baseId,
        '🔔 Hatırlatıcı Açıldı: ${event.title}',
        'Etkinlik yaklaştığında (24 saat kala, sabah ve 30 dk önce) sana bildirim göndereceğiz!',
        platformDetails,
      );
    } catch (e) {
      debugPrint('Anlık bildirim hatası: $e');
    }

    // 1. 24 saat kala
    try {
      final oneDayBefore = eventTime.subtract(const Duration(hours: 24));
      if (oneDayBefore.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          baseId + 4,
          'Yarın Etkinlik Var! 🎟️',
          '${event.title} etkinliğine son 24 saat. Hazır mısın?',
          tz.TZDateTime.from(oneDayBefore, tz.local),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('24 saat kala hatırlatıcı hatası: $e');
    }

    // 2. Gösteri günü sabahı (09:00)
    try {
      final morningOfEvent = DateTime(eventTime.year, eventTime.month, eventTime.day, 9, 0);
      if (morningOfEvent.isAfter(now) && morningOfEvent.isBefore(eventTime)) {
        await _notificationsPlugin.zonedSchedule(
          baseId + 1,
          'Bugün Etkinlik Var! 🎟️',
          '${event.title} bugün ${eventTime.hour.toString().padLeft(2, '0')}:${eventTime.minute.toString().padLeft(2, '0')}\'da. Hazırlanmaya başla!',
          tz.TZDateTime.from(morningOfEvent, tz.local),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Sabah hatırlatıcısı zamanlama hatası: $e');
    }

    // 3. Gösteriye 30 dk kala
    try {
      final thirtyMinsBefore = eventTime.subtract(const Duration(minutes: 30));
      if (thirtyMinsBefore.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          baseId + 2,
          'Etkinlik Başlamak Üzere! ⏰',
          '${event.title} 30 dakika içinde başlıyor. Mekanda buluşalım!',
          tz.TZDateTime.from(thirtyMinsBefore, tz.local),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('30dk hatırlatıcısı zamanlama hatası: $e');
    }

    // 4. Gösteri saati
    try {
      if (eventTime.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          baseId + 3,
          'Etkinlik Başladı! 🎉',
          'Ve beklenen an... ${event.title} başlıyor, iyi eğlenceler!',
          tz.TZDateTime.from(eventTime, tz.local),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Etkinlik saati zamanlama hatası: $e');
    }
  }
}
