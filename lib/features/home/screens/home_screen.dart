import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_match_service.dart';
import '../../events/screens/explore_screen.dart';
import '../../events/screens/requests_screen.dart';
import '../../events/screens/swipe_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/screens/settings_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../../core/theme/theme_service.dart';
import '../../events/services/location_radar_service.dart';
import '../../events/screens/event_map_screen.dart';
import '../../../core/widgets/custom_app_background.dart';

class RadarIconWidget extends StatefulWidget {
  const RadarIconWidget({super.key});

  @override
  State<RadarIconWidget> createState() => _RadarIconWidgetState();
}

class _RadarIconWidgetState extends State<RadarIconWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationRadarService>(
      builder: (context, radarService, child) {
        if (!radarService.isRadarActive) {
          if (_controller.isAnimating) _controller.stop();
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(Icons.radar, color: AppColors.textMuted, size: 20),
          );
        }

        if (!_controller.isAnimating) _controller.repeat();

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (radarService.nearbyUsers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Şu an çevrede kitle aktif görünmüyor.', style: TextStyle(color: Colors.white)),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  return;
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 20),
                        ShaderMask(
                          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                          child: const Icon(Icons.radar, color: Colors.white, size: 52),
                        ),
                            const SizedBox(height: 8),
                            Text('Yakındaki ${radarService.nearbyUsersCount} Kişi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Etkinlik alanında seninle aynı vibedaki insanlar', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(height: 20),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: radarService.nearbyUsers.length,
                                itemBuilder: (context, index) {
                                  final u = radarService.nearbyUsers[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: AppColors.primaryGradient,
                                              ),
                                              child: CircleAvatar(
                                                radius: 26,
                                                backgroundColor: AppColors.background,
                                                backgroundImage: u.avatarUrl.startsWith('http') ? NetworkImage(u.avatarUrl) : null,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(u.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 2),
                                                  if (u.aboutMe != null)
                                                    Text(u.aboutMe!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: AppColors.primaryGradient,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  HapticFeedback.mediumImpact();
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${u.name} kişisine selam gönderildi! ⚡')));
                                                  Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.transparent,
                                                  shadowColor: Colors.transparent,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                ),
                                                icon: const Icon(Icons.waving_hand, color: Colors.white, size: 14),
                                                label: const Text('Selam', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (u.tags.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: u.tags.map((t) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                              ),
                                              child: Text(t, style: TextStyle(color: AppColors.primaryVariant, fontSize: 11, fontWeight: FontWeight.w600)),
                                            )).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${radarService.nearbyUsersCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ExploreScreen(),
    const SwipeScreen(),
    const RequestsScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return CustomAppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                    child: const Text('EventMatch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.map_outlined, color: Colors.white, size: 20),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EventMapScreen()),
                    );
                  },
                ),
                const Center(child: RadarIconWidget()),
                if (_currentIndex == 4)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
              ],
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            bottomNavigationBar: SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    _buildNavItem(0, Icons.explore_outlined, Icons.explore, 'Keşfet'),
                    _buildNavItem(1, Icons.swipe_outlined, Icons.swipe, 'Eşleş'),
                    _buildNavItemWithBadge(2, Icons.favorite_border, Icons.favorite, 'İstekler'),
                    _buildNavItem(3, Icons.message_outlined, Icons.message, 'Mesajlar'),
                    _buildNavItem(4, Icons.person_outline, Icons.person, 'Profil'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: isSelected
                ? BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  size: 20,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return Consumer<MockMatchService>(
      builder: (context, matchService, child) {
        final reqCount = matchService.incomingRequests.length;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = index);
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: isSelected
                    ? BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      )
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: reqCount > 0,
                      label: Text(reqCount.toString()),
                      backgroundColor: AppColors.secondary,
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

