import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// %100 Saf Supabase & Flutter Yerel Bildirim Servisi (WhatsApp Tarzı Heads-up)
class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final StreamController<String?> onNotificationClick = StreamController<String?>.broadcast();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Kullanıcının açık tuttuğu aktif sohbet (Bu sohbet açıkken ve uygulama ön plandayken banner bastırılır)
  String? activeChatId;

  /// Uygulamanın ön planda olup olmadığını takip eder
  bool isAppInForeground = true;

  /// Mükerrer bildirim engelleme önbelleği (2 saniyelik debouncing)
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
      // 1. Yerel Bildirim Ayarları
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

        // Android 13+ bildirim izni iste
        final granted = await androidImpl?.requestNotificationsPermission();
        debugPrint('[NotificationService] 📱 Android Bildirim İzni Durumu: $granted');

        await androidImpl?.createNotificationChannel(highImportanceChannel);
        debugPrint('[NotificationService] 📢 Android high_importance_channel kanalı başarıyla kaydedildi.');
      }

      _isInitialized = true;
      debugPrint('[NotificationService] 🔔 Saf Supabase Bildirim Servisi başarıyla başlatıldı.');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Bildirim servisi başlatma hatası: $e');
    }
  }

  /// Cihaz Push Token'ını Supabase veritabanına kaydeder
  Future<void> registerDeviceToken(String userId, String pushToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_push_token', pushToken);

      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser != null) {
        await supabase.from('users').update({
          'push_token': pushToken,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
        debugPrint('[NotificationService] 📱 Push token veritabanında users/$userId güncellendi.');
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Push token kaydetme hatası: $e');
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
    // 1. Mükerrer bildirim engelleme (debouncing)
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

    // 2. Eğer kullanıcı uygulama İÇİNDEYSE ve O SOHBETTEYSE bildirimi bastır (ekranda yazışıyor zaten)
    // ANCAK: Kullanıcı uygulamada değilse (arka planda / kilitli ekranda), bildirim HER ZAMAN ÇALMALIDIR!
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
      debugPrint('[NotificationService] 📢 WhatsApp tarzı heads-up bildirim gösterildi: $title -> $message (Ön planda mı: $isAppInForeground)');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Bildirim gösterme hatası: $e');
    }
  }
}
