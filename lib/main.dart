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

class EventMatchApp extends StatelessWidget {
  const EventMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'EventMatch',
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}
