import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/event_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

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
    _isInitialized = true;
  }

  static Future<void> showRadarNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'radar_channel',
      'Radar Notifications',
      channelDescription: 'Etkinlik eşleşme radar bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformDetails,
    );
  }

  static Future<void> scheduleEventReminders(EventModel event) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_reminder_channel',
      'Event Reminders',
      channelDescription: 'Etkinlik hatırlatıcı bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final eventTime = event.dateTime;
    final now = DateTime.now();

    // Benzersiz ID'ler oluşturmak için event.id'nin hash'ini kullanalım
    final baseId = event.id.hashCode;

    // 1. Gösteri tarihi gelince (Saat 09:00'da)
    final morningOfEvent = DateTime(eventTime.year, eventTime.month, eventTime.day, 9, 0);
    if (morningOfEvent.isAfter(now) && morningOfEvent.isBefore(eventTime)) {
      await _notificationsPlugin.zonedSchedule(
        baseId + 1,
        'Bugün Etkinlik Var!',
        '${event.title} bugün ${eventTime.hour.toString().padLeft(2, '0')}:${eventTime.minute.toString().padLeft(2, '0')}\'da. Hazırlanmaya başla!',
        tz.TZDateTime.from(morningOfEvent, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 2. Gösteriye 30 dk kala
    final thirtyMinsBefore = eventTime.subtract(const Duration(minutes: 30));
    if (thirtyMinsBefore.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        baseId + 2,
        'Etkinlik Başlamak Üzere!',
        '${event.title} 30 dakika içinde başlıyor. Harekete geç!',
        tz.TZDateTime.from(thirtyMinsBefore, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 3. Gösteri saati
    if (eventTime.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        baseId + 3,
        'Etkinlik Başladı!',
        'Ve beklenen an... ${event.title} başlıyor, iyi eğlenceler!',
        tz.TZDateTime.from(eventTime, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
