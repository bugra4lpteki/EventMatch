import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// En üst seviye (top-level) arka plan & kapalı durum FCM bildirim dinleyicisi
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] 🌙 Arka plan / Kapalı durumda bildirim yakalandı: ${message.messageId}');
  debugPrint('[FCM Background] Veri: ${message.data}');

  // Eğer bildirim sadece data payload olarak geldiyse heads-up göstermek için local notifications oluşturulur
  if (message.notification == null && message.data.isNotEmpty) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final title = message.data['title']?.toString() ?? '💬 Yeni Mesaj';
    final body = message.data['body']?.toString() ?? message.data['content']?.toString() ?? 'Bir mesajınız var.';
    final chatId = message.data['chat_id']?.toString() ?? message.data['sender_id']?.toString() ?? '';

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Yüksek Öncelikli Mesaj Bildirimleri',
      channelDescription: 'WhatsApp tarzı sesli, titreşimli ve tepeden inen mesaj bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      enableVibration: true,
      playSound: true,
      visibility: NotificationVisibility.public,
    );

    await flutterLocalNotificationsPlugin.show(
      chatId.hashCode.abs(),
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'chat_$chatId',
    );
  }
}

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final StreamController<String?> onNotificationClick = StreamController<String?>.broadcast();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isInitialized = false;

  /// Kullanıcının açık tuttuğu aktif sohbet (Bu sohbet açıkken ve uygulama ön plandayken banner bastırılır)
  String? activeChatId;

  /// Uygulamanın ön planda olup olmadığını takip eder
  bool isAppInForeground = true;

  /// Mükerrer bildirim engelleme önbelleği
  final Map<String, DateTime> _recentNotifications = {};

  /// Android Yüksek Öncelikli WhatsApp Bildirim Kanalı
  static const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Yüksek Öncelikli Mesaj Bildirimleri',
    description: 'WhatsApp tarzı sesli, titreşimli ve tepeden inen mesaj bildirimleri',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
    enableLights: true,
    ledColor: Color(0xFFEC4899),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      isAppInForeground = true;
      debugPrint('[NotificationService] 📱 Uygulama ÖN PLANA geldi.');
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached ||
               state == AppLifecycleState.hidden) {
      isAppInForeground = false;
      debugPrint('[NotificationService] 📱 Uygulama ARKA PLANA geçti / kilitlendi.');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Local Notifications Başlatma
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

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] 🔔 Bildirime tıklandı: ${response.payload}');
          if (response.payload != null) {
            onNotificationClick.add(response.payload);
          }
        },
      );

      // 2. Android Kanalını ve İzinlerini Kaydet
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        await androidImpl?.requestNotificationsPermission();
        await androidImpl?.createNotificationChannel(highImportanceChannel);
        debugPrint('[NotificationService] 📢 Android high_importance_channel kanalı başarıyla kaydedildi.');
      }

      // 3. Firebase Messaging İzinleri (iOS & Android 13+)
      final notificationSettings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] 📱 Bildirim İzin Durumu: ${notificationSettings.authorizationStatus}');

      // 4. iOS Foreground Bildirim Seçenekleri
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Ön Plan Mesaj Dinleyicisi (onMessage)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM onMessage] 📩 Ön planda push mesajı alındı: ${message.messageId}');
        _handleIncomingRemoteMessage(message);
      });

      // 6. Arka Plan / Kilitli Ekrandan Tıklanma (onMessageOpenedApp)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM onMessageOpenedApp] 🚀 Bildirime tıklanarak uygulama açıldı: ${message.data}');
        final chatId = message.data['chat_id']?.toString() ?? message.data['sender_id']?.toString();
        if (chatId != null && chatId.isNotEmpty) {
          onNotificationClick.add('chat_$chatId');
        }
      });

      // 7. Uygulama Tamamen Kapalıyken (Terminated) Bildirime Tıklanarak Açılma
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM getInitialMessage] ⚡ Kapalı durumdan bildirimle başlatıldı: ${initialMessage.data}');
        final chatId = initialMessage.data['chat_id']?.toString() ?? initialMessage.data['sender_id']?.toString();
        if (chatId != null && chatId.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            onNotificationClick.add('chat_$chatId');
          });
        }
      }

      // 8. FCM Token Alma & Token Refresh Dinleme
      _initFcmTokens();

      _isInitialized = true;
      debugPrint('[NotificationService] 🔔 Bildirim Servisi ve FCM başarıyla başlatıldı.');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Başlatma hatası: $e');
    }
  }

  void _initFcmTokens() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM Token] 🔑 Alınan FCM Token: $token');
        await _saveAndSyncToken(token);
      }

      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM Token] 🔄 FCM Token yenilendi: $newToken');
        _saveAndSyncToken(newToken);
      });
    } catch (e) {
      debugPrint('[FCM Token] ⚠️ Token alma hatası: $e');
    }
  }

  Future<void> _saveAndSyncToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_push_token', token);

      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await registerDeviceToken(currentUserId, token);
      }
    } catch (e) {
      debugPrint('[NotificationService] Token kaydetme hatası: $e');
    }
  }

  /// Cihaz FCM / Push Token'ını Supabase veritabanına kaydeder
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
        debugPrint('[NotificationService] 📱 Push token veritabanında users/$userId güncellendi.');
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Push token register hatası: $e');
    }
  }

  void _handleIncomingRemoteMessage(RemoteMessage message) {
    final senderName = message.notification?.title ?? message.data['sender_name']?.toString() ?? '💬 Yeni Mesaj';
    final content = message.notification?.body ?? message.data['content']?.toString() ?? message.data['message']?.toString() ?? '';
    final chatId = message.data['chat_id']?.toString() ?? message.data['sender_id']?.toString() ?? 'unknown';

    if (content.isNotEmpty) {
      showMessageNotification(
        chatId: chatId,
        senderName: senderName.replaceFirst('💬 ', ''),
        message: content,
        messageId: message.messageId,
      );
    }
  }

  /// WhatsApp tarzı Heads-up Mesaj Bildirimi (Uygulama arka plandayken veya başka ekrandayken)
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String message,
    int unreadCount = 1,
    String? messageId,
  }) async {
    final dedupeKey = messageId ?? '$chatId:${message.trim()}';
    final now = DateTime.now();
    if (_recentNotifications.containsKey(dedupeKey)) {
      final lastTime = _recentNotifications[dedupeKey]!;
      if (now.difference(lastTime).inSeconds < 2) {
        debugPrint('[NotificationService] ⏭️ Mükerrer bildirim engellendi: $dedupeKey');
        return;
      }
    }
    _recentNotifications[dedupeKey] = now;

    if (_recentNotifications.length > 50) {
      _recentNotifications.removeWhere((_, time) => now.difference(time).inSeconds > 30);
    }

    // Kullanıcı uygulama içinde ve o sohbette ise bildirimi bastır
    if (isAppInForeground && activeChatId != null &&
        (activeChatId == chatId || activeChatId!.toLowerCase() == chatId.toLowerCase())) {
      debugPrint('[NotificationService] 🔕 Kullanıcı ön planda ve aktif sohbette ($chatId), bildirim bastırıldı.');
      return;
    }

    final String title = unreadCount > 1
        ? '💬 $senderName ($unreadCount yeni mesaj)'
        : '💬 $senderName';

    if (kIsWeb) {
      debugPrint('[NotificationService Web] $title: $message');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      highImportanceChannel.id,
      highImportanceChannel.name,
      channelDescription: highImportanceChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      category: AndroidNotificationCategory.message,
      number: unreadCount,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      playSound: true,
      enableLights: true,
      ledColor: const Color(0xFFEC4899),
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'EventMatch Sohbet',
        htmlFormatSummaryText: false,
      ),
      fullScreenIntent: false,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: '💬 $senderName: $message',
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      badgeNumber: unreadCount,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        chatId.hashCode.abs(),
        title,
        message,
        details,
        payload: 'chat_$chatId',
      );
      debugPrint('[NotificationService] 📢 WhatsApp tarzı heads-up bildirim gösterildi: $title -> $message');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Bildirim gösterme hatası: $e');
    }
  }
}
