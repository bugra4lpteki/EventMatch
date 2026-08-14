import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
