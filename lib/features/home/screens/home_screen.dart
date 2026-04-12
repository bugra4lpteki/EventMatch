import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/services/mock_auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_match_service.dart';
import '../../events/screens/explore_screen.dart';
import '../../events/screens/requests_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../admin/screens/admin_panel_screen.dart';
import '../../events/services/location_radar_service.dart';

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
    )..repeat(reverse: true);
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
          // Radar kapalıysa gri soluk bir ikon gösterelim
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: const Icon(Icons.radar, color: AppColors.surface, size: 24),
          );
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return GestureDetector(
              onTap: () {
                if (radarService.nearbyUsers.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şu an çevrede kimse yok.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.surface));
                   return;
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 24),
                        const Icon(Icons.radar, color: AppColors.primary, size: 48),
                        const SizedBox(height: 8),
                        Text('Yakındaki ${radarService.nearbyUsersCount} Kişi', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: radarService.nearbyUsers.length,
                            itemBuilder: (context, index) {
                              final u = radarService.nearbyUsers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.surface,
                                  backgroundImage: u.avatarUrl.startsWith('http') ? NetworkImage(u.avatarUrl) : null,
                                ),
                                title: Text(u.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                subtitle: Text(u.aboutMe ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                     // Sadece görsel geri bildirim
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${u.name} kişisine selam gönderildi!')));
                                     Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary.withOpacity(0.2),
                                    elevation: 0,
                                  ),
                                  child: const Text('Selam Ver', style: TextStyle(color: AppColors.primary)),
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
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2 + (_controller.value * 0.3)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5 + (_controller.value * 0.5)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2 + (_controller.value * 0.4)),
                      blurRadius: 10 + (_controller.value * 10),
                      spreadRadius: 2 + (_controller.value * 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radar, 
                      color: Colors.white, 
                      size: 20 + (_controller.value * 4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${radarService.nearbyUsersCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
    const RequestsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventMatch', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        actions: [
          const Center(child: RadarIconWidget()),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textPrimary),
            onPressed: () {
              context.read<MockAuthService>().logout();
            },
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Keşfet',
            ),
            BottomNavigationBarItem(
              icon: Consumer<MockMatchService>(
                builder: (context, matchService, child) {
                  final reqCount = matchService.incomingRequests.length;
                  return Badge(
                    isLabelVisible: reqCount > 0,
                    label: Text(reqCount.toString()),
                    child: const Icon(Icons.favorite_border),
                  );
                },
              ),
              activeIcon: Consumer<MockMatchService>(
                builder: (context, matchService, child) {
                  final reqCount = matchService.incomingRequests.length;
                  return Badge(
                    isLabelVisible: reqCount > 0,
                    label: Text(reqCount.toString()),
                    child: const Icon(Icons.favorite),
                  );
                },
              ),
              label: 'İstekler',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
