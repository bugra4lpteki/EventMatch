import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/auth/services/auth_service.dart';
import 'features/home/screens/splash_screen.dart';
import 'features/events/services/mock_event_service.dart';
import 'features/events/services/mock_match_service.dart';
import 'features/events/services/location_radar_service.dart';
import 'core/services/notification_service.dart';
import 'features/messages/services/mock_message_service.dart';
import 'features/messages/screens/chat_detail_screen.dart';
import 'features/events/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return Material(
      color: const Color(0xFF08080C),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEC4899), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Görünüm Yüklenirken Bir Hata Oluştu',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
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

  await NotificationService().initialize();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

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
  @override
  void initState() {
    super.initState();
    _setupNotificationNavigation();
  }

  void _setupNotificationNavigation() {
    NotificationService.onNotificationClick.stream.listen((payload) {
      if (payload != null && payload.startsWith('chat_')) {
        final partnerId = payload.replaceFirst('chat_', '');
        if (partnerId.isNotEmpty && navigatorKey.currentState != null) {
          final context = navigatorKey.currentContext;
          if (context != null) {
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
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'EventMatch',
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}
