import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level background message handler (Background / Terminated State)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(Map<String, dynamic> message) async {
  debugPrint('[NotificationService] 🌙 Arka plan bildirimi yakalandı: ${message.toString()}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final StreamController<String?> onNotificationClick = StreamController<String?>.broadcast();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Kullanıcının açık tuttuğu aktif sohbet (Bu sohbet açıkken ses/banner bastırılır)
  String? activeChatId;

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
          debugPrint('[NotificationService] 🔔 Bildirime tıklandı: ${response.payload}');
          if (response.payload != null) {
            onNotificationClick.add(response.payload);
          }
        },
      );

      _isInitialized = true;
      debugPrint('[NotificationService] 🔔 Bildirim Servisi başarıyla başlatıldı.');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Başlatma hatası: $e');
    }
  }

  /// Cihaz FCM Push Token'ını kaydeder
  Future<void> registerDeviceToken(String userId, String pushToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_push_token', pushToken);

      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser != null) {
        await supabase.from('users').update({
          'push_token': pushToken,
          'fcm_token': pushToken,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
        debugPrint('[NotificationService] 📱 Push token veritabanında users/$userId/fcm_token olarak kaydedildi.');
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Push token register hatası: $e');
    }
  }

  /// WhatsApp tarzı Heads-up Mesaj Bildirimi
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String message,
  }) async {
    if (activeChatId != null && (activeChatId == chatId || activeChatId!.toLowerCase() == chatId.toLowerCase())) {
      debugPrint('[NotificationService] 🔕 Kullanıcı aktif sohbette ($chatId), bildirim bastırıldı.');
      return;
    }

    if (kIsWeb) {
      debugPrint('[NotificationService Web] 💬 $senderName: $message');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'event_match_chat_channel',
      'Mesaj Bildirimleri',
      channelDescription: 'Anlık sohbet ve eşleşme mesaj bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.message,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        chatId.hashCode,
        '💬 $senderName',
        message,
        details,
        payload: 'chat_$chatId',
      );
      debugPrint('[NotificationService] 📢 Bildirim gösterildi: $senderName -> $message');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Bildirim gösterme hatası: $e');
    }
  }
}
