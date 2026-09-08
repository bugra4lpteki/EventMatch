import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/onesignal_config.dart';

/// EventMatch Gelişmiş Bildirim Servisi (OneSignal + Yerel Heads-up WhatsApp Bildirimleri)
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
      // 1. Yerel Bildirim Motorunu Başlat (Local Notifications)
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
          debugPrint('[NotificationService] 🔔 Yerel bildirime tıklandı: ${response.payload}');
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

      // 3. OneSignal Başlatma (Uygulama tamamen kapalıyken bile Apple/Google üzerinden push atar)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _initOneSignal();
      }

      _isInitialized = true;
      debugPrint('[NotificationService] 🔔 OneSignal & Yerel Bildirim Servisi başarıyla başlatıldı.');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Bildirim servisi başlatma hatası: $e');
    }
  }

  Future<void> _initOneSignal() async {
    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // OneSignal App ID ile başlat
      OneSignal.initialize(OneSignalConfig.appId);

      // iOS & Android 13+ Bildirim İzni İste
      final permission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('[OneSignal] 📱 Bildirim izni sonucu: $permission');

      // Bildirime tıklandığında sohbete yönlendir
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        debugPrint('[OneSignal Click] 🚀 Bildirime tıklandı: $data');
        final chatId = data?['chat_id']?.toString() ?? data?['sender_id']?.toString();
        if (chatId != null && chatId.isNotEmpty) {
          onNotificationClick.add('chat_$chatId');
        }
      });

      // Ön plandayken bildirim davranışını yönet
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final data = event.notification.additionalData;
        final chatId = data?['chat_id']?.toString() ?? data?['sender_id']?.toString();

        // Eğer kullanıcı o anda o sohbet ekranındaysa ön plan bildirimini bastır
        if (isAppInForeground && activeChatId != null && chatId != null &&
            (activeChatId == chatId || activeChatId!.toLowerCase() == chatId.toLowerCase())) {
          event.preventDefault();
        } else {
          event.notification.display();
        }
      });

      // Eğer kullanıcı zaten giriş yapmışsa OneSignal ile bağla
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        syncUserWithOneSignal(currentUser.id);
      }
    } catch (e) {
      debugPrint('[OneSignal] ⚠️ Başlatma hatası: $e');
    }
  }

  /// Kullanıcı giriş yaptığında OneSignal External ID ve Push Token'ını Supabase ile senkronize eder
  Future<void> syncUserWithOneSignal(String userId) async {
    try {
      if (kIsWeb) return;

      // 1. OneSignal external_id olarak Supabase User ID'sini bağla
      await OneSignal.login(userId);
      debugPrint('[OneSignal] 👤 OneSignal login yapıldı: $userId');

      // 2. Cihaz Player/Subscription ID'sini anında al ve Supabase'e kaydet
      void checkAndSaveToken() {
        final pushSubId = OneSignal.User.pushSubscription.id;
        final pushTok = OneSignal.User.pushSubscription.token;
        final token = pushSubId ?? pushTok;
        if (token != null && token.isNotEmpty) {
          registerDeviceToken(userId, token);
        }
      }

      checkAndSaveToken();

      // Kısa bir gecikmeyle tekrar dene (APNs token gecikmeli atanabilir)
      Future.delayed(const Duration(milliseconds: 1500), checkAndSaveToken);
      Future.delayed(const Duration(seconds: 4), checkAndSaveToken);

      // Subscription değişikliklerini dinle
      OneSignal.User.pushSubscription.addObserver((state) {
        final newId = state.current.id;
        if (newId != null && newId.isNotEmpty) {
          registerDeviceToken(userId, newId);
        }
      });
    } catch (e) {
      debugPrint('[OneSignal] ⚠️ Sync hatası: $e');
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
          'fcm_token': pushToken,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
        debugPrint('[NotificationService] 📱 OneSignal/Push token veritabanında users/$userId güncellendi: $pushToken');
      }
    } catch (e) {
      debugPrint('[NotificationService] ❌ Push token kaydetme hatası: $e');
    }
  }

  /// OneSignal REST API üzerinden alıcıya doğrudan anlık push bildirimi gönderir
  Future<void> sendRemotePushNotification({
    required String receiverId,
    required String senderName,
    required String content,
    String? matchId,
    String? senderId,
  }) async {
    try {
      if (receiverId.isEmpty) return;

      // Alıcının kayıtlı Player/Subscription ID'sini veritabanından çek (Çift Garanti)
      String? receiverPushToken;
      try {
        final uRes = await Supabase.instance.client
            .from('users')
            .select('push_token')
            .eq('id', receiverId)
            .maybeSingle();
        receiverPushToken = uRes?['push_token']?.toString();
      } catch (_) {}

      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final Map<String, dynamic> payload = {
        'app_id': OneSignalConfig.appId,
        'include_external_user_ids': [receiverId.toLowerCase(), receiverId],
        'channel_for_external_user_ids': 'push',
        'priority': 10,
        'android_priority': 5,
        'headings': {
          'tr': '💬 $senderName',
          'en': '💬 $senderName',
        },
        'contents': {
          'tr': content,
          'en': content,
        },
        'data': {
          'chat_id': senderId ?? '',
          'sender_id': senderId ?? '',
          'sender_name': senderName,
          'match_id': matchId ?? '',
          'type': 'new_message',
        },
        'ios_badgeType': 'Increase',
        'ios_badgeCount': 1,
        'ios_sound': 'default',
        'android_sound': 'default',
        'android_channel_id': 'high_importance_channel',
        'apns_priority': 10,
        'content_available': true,
      };

      if (receiverPushToken != null && receiverPushToken.isNotEmpty) {
        payload['include_player_ids'] = [receiverPushToken];
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key ${OneSignalConfig.restApiKey}',
        },
        body: jsonEncode(payload),
      );

      debugPrint('[NotificationService] 🚀 OneSignal Push gönderildi ($receiverId): status ${response.statusCode}');
    } catch (e) {
      debugPrint('[NotificationService] ❌ OneSignal Push gönderme hatası: $e');
    }
  }

  /// Yeni Eşleşme İsteği için anında Push Bildirimi Gönderir
  Future<void> sendMatchRequestPushNotification({
    required String receiverId,
    required String senderName,
    String? source,
  }) async {
    try {
      if (receiverId.isEmpty) return;

      String? receiverPushToken;
      try {
        final uRes = await Supabase.instance.client
            .from('users')
            .select('push_token')
            .eq('id', receiverId)
            .maybeSingle();
        receiverPushToken = uRes?['push_token']?.toString();
      } catch (_) {}

      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final Map<String, dynamic> payload = {
        'app_id': OneSignalConfig.appId,
        'include_external_user_ids': [receiverId.toLowerCase(), receiverId],
        'channel_for_external_user_ids': 'push',
        'priority': 10,
        'android_priority': 5,
        'headings': {
          'tr': '⚡ Yeni Eşleşme İsteği!',
          'en': '⚡ New Match Request!',
        },
        'contents': {
          'tr': '$senderName seninle tanışmak istiyor! İstekler sekmesinden hemen yanıt ver.',
          'en': '$senderName sent you a match request!',
        },
        'data': {
          'type': 'match_request',
          'source': source ?? 'radar',
        },
        'ios_badgeType': 'Increase',
        'ios_badgeCount': 1,
        'ios_sound': 'default',
        'android_sound': 'default',
        'android_channel_id': 'high_importance_channel',
        'apns_priority': 10,
        'content_available': true,
      };

      if (receiverPushToken != null && receiverPushToken.isNotEmpty) {
        payload['include_player_ids'] = [receiverPushToken];
      }

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key ${OneSignalConfig.restApiKey}',
        },
        body: jsonEncode(payload),
      );
      debugPrint('[NotificationService] ⚡ Eşleşme isteği bildirimi gönderildi -> $receiverId');
    } catch (e) {
      debugPrint('[NotificationService] ⚠️ Eşleşme isteği bildirim hatası: $e');
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
      debugPrint('[NotificationService] 📢 WhatsApp tarzı heads-up bildirim gösterildi: $title -> $message (Ön planda mı: $isAppInForeground)');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Bildirim gösterme hatası: $e');
    }
  }
}
