import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/location_radar_service.dart';
import '../../events/models/event_model.dart';
import '../../events/screens/event_detail_screen.dart';
import '../../admin/widgets/secret_admin_dialog.dart';
import 'dart:async';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late PageController _pageController;
  int _currentPhotoIndex = 0;
  int _secretTapCount = 0;
  Timer? _secretTapTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _handleSecretTap() {
    _secretTapCount++;
    _secretTapTimer?.cancel();
    _secretTapTimer = Timer(const Duration(seconds: 3), () {
      _secretTapCount = 0;
    });

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      SecretAdminAuthHelper.showSecretPinDialog(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _secretTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final user = eventService.currentUser;

    final plannedEvents = user.plannedEvents
        .map((id) => eventService.getEventById(id))
        .whereType<EventModel>()
        .toList();

    final pastEvents = user.pastEvents
        .map((id) => eventService.getEventById(id))
        .whereType<EventModel>()
        .toList();

    final rawPhotos = user.avatarUrls.isNotEmpty ? user.avatarUrls : (user.avatarUrl.isNotEmpty ? [user.avatarUrl] : <String>[]);
    final displayPhotos = rawPhotos.where(UserModel.isValidPhotoUrl).toList();
    final recentVenues = plannedEvents.isNotEmpty ? plannedEvents : pastEvents;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero Profile Card ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: SizedBox(
                  height: 380,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background images (PageView)
                      if (displayPhotos.isEmpty)
                        _defaultHeroBg(context)
                      else ...[
                        PageView.builder(
                          controller: _pageController,
                          scrollBehavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          itemCount: displayPhotos.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPhotoIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final photoUrl = displayPhotos[index];
                            if (photoUrl.isEmpty) return _defaultHeroBg(context);
                            return RepaintBoundary(
                              child: AppImageWidget(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 720,
                                memCacheHeight: 900,
                              ),
                            );
                          },
                        ),
                        // Bottom subtle gradient for indicators only
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent],
                                stops: const [0.0, 0.15],
                              ),
                            ),
                          ),
                        ),
                        // Page Indicators
                        if (displayPhotos.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(displayPhotos.length, (index) {
                                  final isActive = _currentPhotoIndex == index;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isActive ? 24 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.textPrimary
                                          : AppColors.textPrimary.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                      ],
                      // Top Quick Action Buttons (Edit Profile & Settings)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildGlassCircleButton(
                              icon: Icons.edit_rounded,
                              tooltip: 'Profili Düzenle',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildGlassCircleButton(
                              icon: Icons.settings_rounded,
                              tooltip: 'Ayarlar',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── User Info Card ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                   GestureDetector(
                                     onTap: _handleSecretTap,
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Text(
                                           user.name,
                                           style: TextStyle(
                                             color: AppColors.textPrimary,
                                             fontSize: 24,
                                             fontWeight: FontWeight.bold,
                                             letterSpacing: -0.4,
                                           ),
                                         ),
                                         if (user.isVerified) ...[
                                           const SizedBox(width: 6),
                                           const Icon(Icons.verified_rounded, size: 22, color: Color(0xFF38BDF8)),
                                         ],
                                       ],
                                     ),
                                   ),
                                  Row(
                                    children: user.socialLinks.take(5).map((link) {
                                      if (link.isEmpty) return const SizedBox.shrink();
                                      return IconButton(
                                        icon: _getSocialIcon(link),
                                        onPressed: () => _launchUrl(link, _getSocialPrefix(link)),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        constraints: const BoxConstraints(),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                              if (user.username != null && user.username!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user.username!.trim().replaceAll('@', ''),
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${user.age ?? '26'} • ${user.city != null && user.city!.isNotEmpty ? user.city : 'İstanbul'}',
                                style: TextStyle(
                                  color: AppColors.textPrimary.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                      ),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Profili Düzenle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                                      tooltip: 'Ayarlar',
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Bio ───────────────────────────────────────────────
                if (user.aboutMe != null && user.aboutMe!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      user.aboutMe!,
                      style: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.9),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Hobiler ───────────────────────────────────────────
                if (user.tags.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // ── Gideceğim Etkinlikler ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Gideceğim Etkinlikler 🎟️',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showAllEventsBottomSheet(context, recentVenues),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'Tümünü Gör',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 168,
                  child: recentVenues.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Henüz katılacağın bir etkinlik seçmedin.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
                          ),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: recentVenues.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (_, i) => _VenueCard(event: recentVenues[i]),
                          ),
                        ),
                ),

                const SizedBox(height: 30),



                // ── Radar Ayarları ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Consumer<LocationRadarService>(
                      builder: (context, radarService, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.radar,
                                      color: radarService.isRadarActive ? AppColors.primary : Colors.grey,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Konum Radarı',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: radarService.isRadarActive,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) => radarService.toggleRadar(val),
                                ),
                              ],
                            ),
                            if (radarService.isRadarActive) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Tarama Yarıçapı: ${radarService.radarDistanceKm.toInt()} km',
                                style: TextStyle(color: AppColors.textPrimary.withOpacity(0.7), fontSize: 14),
                              ),
                              Slider(
                                value: radarService.radarDistanceKm,
                                min: 1,
                                max: 50,
                                divisions: 49,
                                activeColor: AppColors.primary,
                                inactiveColor: Colors.grey.withOpacity(0.3),
                                onChanged: (val) => radarService.updateRadarDistance(val),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String input, String prefix) async {
    String finalUrl = input.trim();
    if (finalUrl.isEmpty) return;
    
    if (!finalUrl.startsWith('http')) {
      if (finalUrl.contains('.com')) {
        finalUrl = 'https://$finalUrl';
      } else {
        // If it's just a username, append the prefix
        finalUrl = 'https://$prefix$finalUrl';
      }
    }
    await UrlLauncherHelper.launchURL(finalUrl);
  }

  Widget _getSocialIcon(String url) {
    final lUrl = url.toLowerCase();
    final iconColor = AppColors.textPrimary.withOpacity(0.7);
    if (lUrl.contains('instagram')) return FaIcon(FontAwesomeIcons.instagram, color: iconColor, size: 22);
    if (lUrl.contains('twitter') || lUrl.contains('x.com')) return FaIcon(FontAwesomeIcons.xTwitter, color: iconColor, size: 22);
    if (lUrl.contains('linkedin')) return FaIcon(FontAwesomeIcons.linkedin, color: iconColor, size: 22);
    if (lUrl.contains('tiktok')) return FaIcon(FontAwesomeIcons.tiktok, color: iconColor, size: 22);
    if (lUrl.contains('facebook')) return FaIcon(FontAwesomeIcons.facebook, color: iconColor, size: 22);
    if (lUrl.contains('youtube')) return FaIcon(FontAwesomeIcons.youtube, color: iconColor, size: 22);
    if (lUrl.contains('github')) return FaIcon(FontAwesomeIcons.github, color: iconColor, size: 22);
    if (lUrl.contains('snapchat')) return FaIcon(FontAwesomeIcons.snapchat, color: iconColor, size: 22);
    if (lUrl.contains('spotify')) return FaIcon(FontAwesomeIcons.spotify, color: iconColor, size: 22);
    return FaIcon(FontAwesomeIcons.link, color: iconColor, size: 22);
  }

  String _getSocialPrefix(String url) {
    final lUrl = url.toLowerCase();
    if (lUrl.contains('instagram')) return 'instagram.com/';
    if (lUrl.contains('twitter') || lUrl.contains('x.com')) return 'x.com/';
    if (lUrl.contains('linkedin')) return 'linkedin.com/in/';
    if (lUrl.contains('tiktok')) return 'tiktok.com/@';
    if (lUrl.contains('facebook')) return 'facebook.com/';
    if (lUrl.contains('youtube')) return 'youtube.com/@';
    if (lUrl.contains('github')) return 'github.com/';
    if (lUrl.contains('snapchat')) return 'snapchat.com/add/';
    if (lUrl.contains('spotify')) return 'open.spotify.com/user/';
    return '';
  }

  Widget _defaultHeroBg(BuildContext context) {
    final user = context.read<MockEventService>().currentUser;
    return UserHeroAvatarCard(
      gender: user.gender,
      name: user.name,
      height: 380,
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            tooltip: tooltip,
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  void _showAllEventsBottomSheet(BuildContext context, List<EventModel> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Etkinliklerim (${events.length})',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz bir etkinlik bulunmuyor.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final event = events[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          tileColor: Colors.white.withValues(alpha: 0.04),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: AppImageWidget(
                                imageUrl: event.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${event.dateTime.day}.${event.dateTime.month}.${event.dateTime.year} • ${event.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Venue Card ─────────────────────────────────────────────────────────────────
class _VenueCard extends StatelessWidget {
  final EventModel event;
  const _VenueCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 148,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: AppImageWidget(
                      imageUrl: event.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      memCacheHeight: 200,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.25)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: AppColors.textSecondary, size: 10),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        event.location.contains(' - ')
                            ? event.location.split(' - ').last
                            : event.location,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
