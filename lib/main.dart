import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/services/mock_auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/events/services/mock_event_service.dart';
import 'features/events/services/mock_match_service.dart';
import 'features/events/services/location_radar_service.dart';
import 'features/events/services/notification_service.dart';
import 'features/messages/services/mock_message_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MockAuthService()),
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
    return MaterialApp(
      title: 'EventMatch',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<MockAuthService>(
        builder: (context, auth, child) {
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
