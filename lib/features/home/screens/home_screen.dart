import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_match_service.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/screens/explore_screen.dart';
import '../../events/screens/requests_screen.dart';
import '../../events/screens/swipe_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/screens/settings_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../messages/services/mock_message_service.dart';
import '../../../core/theme/theme_service.dart';
import '../../events/services/location_radar_service.dart';
import '../../events/screens/event_map_screen.dart';
import '../../../core/widgets/custom_app_background.dart';
import '../../events/widgets/match_dialog.dart';
import '../../messages/screens/chat_detail_screen.dart';
import '../../../services/notification_service.dart';

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
          return GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await radarService.toggleRadar(true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.radar, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Radar Aktifleştirildi! 📡 Yakındaki kişiler taranıyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Icon(Icons.radar, color: AppColors.primary, size: 20),
            ),
          );
        }

        if (!_controller.isAnimating) _controller.repeat();

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return GestureDetector(
              onLongPress: () async {
                HapticFeedback.heavyImpact();
                await radarService.toggleRadar(false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.radar, color: Colors.white70, size: 20),
                          SizedBox(width: 8),
                          Text('Radar kapatıldı. 🛑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      backgroundColor: Colors.grey.shade900,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );
                }
              },
              onTap: () {
                HapticFeedback.lightImpact();
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 40),
                            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Kapat',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                          child: const Icon(Icons.radar, color: Colors.white, size: 52),
                        ),
                        const SizedBox(height: 8),
                        Text('Yakındaki ${radarService.nearbyUsersCount} Kişi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Etkinlik alanında seninle aynı vibedaki insanlar', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        // Radar Kapatma Butonu
                        OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            HapticFeedback.heavyImpact();
                            await radarService.toggleRadar(false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.radar, color: Colors.white70, size: 20),
                                      SizedBox(width: 8),
                                      Text('Radar kapatıldı. 🛑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  backgroundColor: Colors.grey.shade900,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 18),
                          label: const Text('Radarı Kapat', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        if (radarService.nearbyUsers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                Icon(Icons.wifi_tethering_rounded, color: AppColors.primary.withOpacity(0.6), size: 44),
                                const SizedBox(height: 12),
                                Text(
                                  'Şu an yakında radar açmış kullanıcı bulunmuyor.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Radarınız arka planda taranmaya devam ediyor.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: radarService.nearbyUsers.length,
                                itemBuilder: (context, index) {
                                  final u = radarService.nearbyUsers[index];
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(22),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
                                      );
                                    },
                                    child: Container(
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
                                                  child: !u.avatarUrl.startsWith('http')
                                                      ? const Icon(Icons.person, color: Colors.white)
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(u.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 2),
                                                    if (u.aboutMe != null && u.aboutMe!.isNotEmpty)
                                                      Text(u.aboutMe!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              Consumer<MockMatchService>(
                                                 builder: (context, matchService, _) {
                                                   final hasSent = matchService.hasSentRequest('radar', u.id);
                                                   final msgService = context.read<MockMessageService>();
                                                   final isAlreadyMatched = msgService.individualChats.any((c) => c.participant.id.toLowerCase() == u.id.toLowerCase());

                                                   if (isAlreadyMatched) {
                                                     return Container(
                                                       decoration: BoxDecoration(
                                                         color: AppColors.surface,
                                                         borderRadius: BorderRadius.circular(14),
                                                         border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                                       ),
                                                       child: ElevatedButton.icon(
                                                         onPressed: () {
                                                           Navigator.pop(context);
                                                           final chat = msgService.individualChats.firstWhere((c) => c.participant.id.toLowerCase() == u.id.toLowerCase());
                                                           Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)));
                                                         },
                                                         style: ElevatedButton.styleFrom(
                                                           backgroundColor: Colors.transparent,
                                                           shadowColor: Colors.transparent,
                                                           elevation: 0,
                                                           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                         ),
                                                         icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 14),
                                                         label: const Text('Sohbet', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                       ),
                                                     );
                                                   }

                                                   return Container(
                                                     decoration: BoxDecoration(
                                                       gradient: hasSent ? null : AppColors.primaryGradient,
                                                       color: hasSent ? Colors.white.withOpacity(0.1) : null,
                                                       borderRadius: BorderRadius.circular(14),
                                                     ),
                                                     child: ElevatedButton.icon(
                                                       onPressed: hasSent
                                                           ? null
                                                           : () async {
                                                               HapticFeedback.mediumImpact();
                                                               final isMutual = await matchService.sendRadarRequest(u);
                                                               if (isMutual && context.mounted) {
                                                                 final chat = msgService.createOrGetChatForUser(u);
                                                                 await msgService.reloadChats();
                                                                 Navigator.pop(context);
                                                                 MatchDialog.show(
                                                                   context,
                                                                   matchedUser: u,
                                                                   onSendMessage: () {
                                                                     Navigator.push(
                                                                       context,
                                                                       MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
                                                                     );
                                                                   },
                                                                 );
                                                               } else if (context.mounted) {
                                                                 final myName = context.read<MockEventService>().currentUser.name;
                                                                 NotificationService().sendMatchRequestPushNotification(
                                                                   receiverId: u.id,
                                                                   senderName: myName.isNotEmpty ? myName : 'Biri',
                                                                   source: 'radar',
                                                                 );
                                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                                   SnackBar(
                                                                     content: Text('⚡ ${u.name} kişisine eşleşme isteği gönderildi! Kabul ettiğinde sohbetiniz başlayacak.'),
                                                                     backgroundColor: AppColors.primary,
                                                                     behavior: SnackBarBehavior.floating,
                                                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                   ),
                                                                 );
                                                               }
                                                             },
                                                       style: ElevatedButton.styleFrom(
                                                         backgroundColor: Colors.transparent,
                                                         shadowColor: Colors.transparent,
                                                         elevation: 0,
                                                         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                       ),
                                                       icon: Icon(
                                                         hasSent ? Icons.check_circle_outline_rounded : Icons.person_add_rounded,
                                                         color: hasSent ? Colors.white54 : Colors.white,
                                                         size: 14,
                                                       ),
                                                       label: Text(
                                                         hasSent ? 'İstek Gönderildi' : 'İstek Gönder',
                                                         style: TextStyle(
                                                           color: hasSent ? Colors.white54 : Colors.white,
                                                           fontSize: 12,
                                                           fontWeight: FontWeight.bold,
                                                         ),
                                                       ),
                                                     ),
                                                   );
                                                 },
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

  final List<Widget> _pages = const [
    ExploreScreen(key: PageStorageKey('ExploreScreen')),
    SwipeScreen(key: PageStorageKey('SwipeScreen')),
    RequestsScreen(key: PageStorageKey('RequestsScreen')),
    MessagesScreen(key: PageStorageKey('MessagesScreen')),
    ProfileScreen(key: PageStorageKey('ProfileScreen')),
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
                      color: Colors.white.withValues(alpha: 0.06),
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
                        color: Colors.white.withValues(alpha: 0.06),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: [
                      _buildNavItem(0, Icons.explore_outlined, Icons.explore_rounded, 'Keşfet'),
                      _buildNavItem(1, Icons.local_fire_department_outlined, Icons.local_fire_department_rounded, 'Eşleş'),
                      _buildNavItemWithBadge(2, Icons.favorite_border_rounded, Icons.favorite_rounded, 'İstekler'),
                      _buildNavItem(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Mesajlar'),
                      _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
                    ],
                  ),
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
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 8, vertical: 8),
            decoration: isSelected
                ? BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : AppColors.textSecondary.withOpacity(0.7),
                  size: 20,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.2,
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
              if (_currentIndex != index) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 8, vertical: 8),
                decoration: isSelected
                    ? BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      )
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
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
                        color: isSelected ? Colors.white : AppColors.textSecondary.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.2,
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
