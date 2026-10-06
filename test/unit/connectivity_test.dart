import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_match/core/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConnectivityResult enums are available', () {
    expect(ConnectivityResult.none, isNotNull);
    expect(ConnectivityResult.wifi, isNotNull);
    expect(ConnectivityResult.mobile, isNotNull);
  });

  test('ConnectivityService singleton instance created with default state', () {
    final service = ConnectivityService();
    expect(service, isNotNull);
    expect(service.isOnline, isTrue);
    expect(service.isOffline, isFalse);
    expect(service.showRestoredBanner, isFalse);
  });
}
