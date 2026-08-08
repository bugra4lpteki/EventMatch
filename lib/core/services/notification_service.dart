import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );
      _isInitialized = true;
      debugPrint('[NotificationService] 🔔 Notification Service initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (kIsWeb) {
      debugPrint('[NotificationService Web] 🔔 $title: $body');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'event_match_channel',
      'EventMatch Bildirimleri',
      channelDescription: 'Eşleşme, mesaj ve etkinlik bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('[NotificationService] Show error: $e');
    }
  }

  Future<void> showMatchNotification(String userName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎉 Yeni Eşleşme Yakaladın!',
      body: '$userName ile aynı vibedadasınız! Hemen selam gönder ⚡',
      payload: 'match_$userName',
    );
  }

  Future<void> showMessageNotification(String senderName, String message) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '💬 $senderName',
      body: message,
      payload: 'chat_$senderName',
    );
  }

  Future<void> showEventReminder(String eventTitle, String location) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎟️ Etkinlik Hatırlatıcı',
      body: '$eventTitle bugün $location adresinde başlıyor!',
      payload: 'event_$eventTitle',
    );
  }
}
