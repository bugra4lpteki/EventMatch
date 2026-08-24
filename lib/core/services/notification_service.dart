import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final StreamController<String?> onNotificationClick = StreamController<String?>.broadcast();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Kullanıcının şu an aktif olarak açık tuttuğu sohbet ID'si (Açıkken bildirim sesi/banner'ı bastırılır)
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
      debugPrint('[NotificationService] 🔔 WhatsApp tarzı Bildirim Servisi hazırlandı.');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
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
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
        debugPrint('[NotificationService] 📱 Push token veritabanında güncellendi.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Push token register error: $e');
    }
  }

  /// WhatsApp tarzı Heads-up Mesaj Bildirimi
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String message,
    String? avatarUrl,
  }) async {
    // Eğer kullanıcı zaten bu sohbetteyse bildirimi bastır (WhatsApp mantığı)
    if (activeChatId != null && (activeChatId == chatId || activeChatId!.toLowerCase() == chatId.toLowerCase())) {
      debugPrint('[NotificationService] 🔕 Kullanıcı aktif sohbette, bildirim bastırıldı.');
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
      styleInformation: DefaultStyleInformation(true, true),
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
        senderName,
        message,
        details,
        payload: 'chat_$chatId',
      );
    } catch (e) {
      debugPrint('[NotificationService] Show message error: $e');
    }
  }

  /// Yeni Eşleşme Bildirimi
  Future<void> showMatchNotification(String userName, String userId) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'event_match_matches_channel',
      'Eşleşme Bildirimleri',
      channelDescription: 'Yeni eşleşme ve beğeni bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    try {
      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🎉 Tebrikler, Yeni Bir Eşleşme!',
        '$userName ile eşleştiniz. Hemen sohbete başlayın! ⚡',
        details,
        payload: 'match_$userId',
      );
    } catch (e) {
      debugPrint('[NotificationService] Show match error: $e');
    }
  }
}
