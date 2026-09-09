import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/auth/services/auth_service.dart';
import 'features/home/screens/splash_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/events/services/mock_event_service.dart';
import 'features/events/services/mock_match_service.dart';
import 'features/events/services/location_radar_service.dart';
import 'services/notification_service.dart';
import 'features/messages/services/mock_message_service.dart';
import 'features/messages/screens/chat_detail_screen.dart';
import 'features/events/models/user_model.dart';
import 'features/events/services/spotify_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Supabase Başlat (Tüm servislerden önce hazır olmalı)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // 2. Yüksek Öncelikli WhatsApp Tarzı Bildirim & OneSignal Servisini Başlat
  await NotificationService().initialize();

  // Halihazırda oturum açmış kullanıcı varsa OneSignal ile anında eşle
  final existingUser = Supabase.instance.client.auth.currentUser;
  if (existingUser != null) {
    NotificationService().syncUserWithOneSignal(existingUser.id);
  }

  // Sanatçı görsel cache'ini sıfırla: eski albüm kapağı URL'leri kalmasın,
  // Wikipedia / Deezer'dan gerçek sanatçı fotoğrafı çekilsin.
  SpotifyService().clearCache();

  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    debugPrint('DateFormatting init error: $e');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[EventMatch Global Error] ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[EventMatch Platform Error] $error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      color: Color(0xFF08080C),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFEC4899), size: 48),
              SizedBox(height: 16),
              Text(
                'Görünüm Yüklenirken Bir Hata Oluştu',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Lütfen uygulamayı yenileyin veya tekrar deneyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MockEventService()),
        ChangeNotifierProxyProvider<MockEventService, MockMatchService>(
          create: (context) => MockMatchService(context.read<MockEventService>()),
          update: (context, eventService, matchService) => matchService ?? MockMatchService(eventService),
        ),
        ChangeNotifierProxyProvider<MockEventService, MockMessageService>(
          create: (context) => MockMessageService(context.read<MockEventService>()),
          update: (context, eventService, msgService) => msgService ?? MockMessageService(eventService),
        ),
        ChangeNotifierProxyProvider<MockEventService, LocationRadarService>(
          create: (context) => LocationRadarService(context.read<MockEventService>()),
          update: (context, eventService, radarService) => radarService ?? LocationRadarService(eventService),
        ),
      ],
      child: const EventMatchApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class EventMatchApp extends StatefulWidget {
  const EventMatchApp({super.key});

  @override
  State<EventMatchApp> createState() => _EventMatchAppState();
}

class _EventMatchAppState extends State<EventMatchApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _setupNotificationNavigation();
  }

  /// Supabase Auth Durum Değişikliği Dinleyicisi
  /// Google/Apple OAuth veya e-posta ile giriş yapıldığında profili yükler ve yönlendirir.
  void _setupAuthListener() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('[Auth] onAuthStateChange event: $event');

      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      final userId = data.session?.user.id;
      if (userId != null) {
        NotificationService().syncUserWithOneSignal(userId);
      }

      if (event == AuthChangeEvent.signedIn) {
        ctx.read<MockEventService>().loadUserProfile();
      } else if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
        );
      }
    });
  }

  void _setupNotificationNavigation() {
    NotificationService.onNotificationClick.stream.listen((payload) {
      if (payload != null && payload.startsWith('chat_')) {
        final partnerId = payload.replaceFirst('chat_', '');
        if (partnerId.isNotEmpty && navigatorKey.currentState != null) {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final msgService = context.read<MockMessageService>();
            final chat = msgService.individualChats.firstWhere(
              (c) => c.id == partnerId || c.participant.id.toLowerCase() == partnerId.toLowerCase(),
              orElse: () => msgService.createOrGetChatForUser(
                UserModel(id: partnerId, name: 'Kullanıcı', avatarUrl: ''),
              ),
            );

            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(chat: chat),
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'EventMatch',
          theme: AppTheme.getTheme(isLight: themeService.isLightTheme),
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}
