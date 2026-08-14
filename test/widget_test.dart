import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_match/main.dart';
import 'package:event_match/core/theme/theme_service.dart';
import 'package:event_match/features/auth/services/auth_service.dart';
import 'package:event_match/features/events/services/mock_event_service.dart';
import 'package:event_match/features/events/services/mock_match_service.dart';
import 'package:event_match/features/messages/services/mock_message_service.dart';
import 'package:event_match/features/events/services/location_radar_service.dart';
import 'package:event_match/core/constants/supabase_config.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (_) {}
  });

  testWidgets('EventMatchApp smoke test', (WidgetTester tester) async {
    final eventService = MockEventService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => eventService),
          ChangeNotifierProxyProvider<MockEventService, MockMatchService>(
            create: (context) => MockMatchService(eventService),
            update: (context, es, ms) => ms ?? MockMatchService(es),
          ),
          ChangeNotifierProxyProvider<MockEventService, MockMessageService>(
            create: (context) => MockMessageService(eventService),
            update: (context, es, ms) => ms ?? MockMessageService(es),
          ),
          ChangeNotifierProxyProvider<MockEventService, LocationRadarService>(
            create: (context) => LocationRadarService(eventService),
            update: (context, es, rs) => rs ?? LocationRadarService(es),
          ),
        ],
        child: const EventMatchApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
