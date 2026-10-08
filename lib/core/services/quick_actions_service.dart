import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// iOS Haptic Touch / 3D Touch Ana Ekran Kısayolları (Quick Actions)
class QuickActionsService {
  static final QuickActionsService _instance = QuickActionsService._internal();
  factory QuickActionsService() => _instance;
  QuickActionsService._internal();

  final QuickActions _quickActions = const QuickActions();

  /// Kısayola basıldığında tetiklenecek fonksiyon
  static void Function(String shortcutType)? onShortcutTapped;

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      _quickActions.initialize((String shortcutType) {
        debugPrint('[QuickActions] Ana ekran kısayoluna tıklandı: $shortcutType');
        onShortcutTapped?.call(shortcutType);
      });

      await _quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
          type: 'shortcut_radar',
          localizedTitle: 'Eşleşme Radarı',
          icon: 'AppIcon',
        ),
        const ShortcutItem(
          type: 'shortcut_nearby',
          localizedTitle: 'Yakındaki Etkinlikler',
          icon: 'AppIcon',
        ),
        const ShortcutItem(
          type: 'shortcut_my_events',
          localizedTitle: 'Biletlerim & Etkinlikler',
          icon: 'AppIcon',
        ),
        const ShortcutItem(
          type: 'shortcut_vip',
          localizedTitle: 'VIP Ayrıcalıkları 👑',
          icon: 'AppIcon',
        ),
      ]);
    } catch (e) {
      debugPrint('[QuickActions] Init error: $e');
    }
  }
}
