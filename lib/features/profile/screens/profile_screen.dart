import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/location_radar_service.dart';
import '../../events/models/event_model.dart';
import '../../events/screens/event_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentPhotoIndex = 0;

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

    final displayPhotos = user.avatarUrls.isNotEmpty ? user.avatarUrls : (user.avatarUrl.isNotEmpty ? [user.avatarUrl] : <String>[]);
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
                      else
                        PageView.builder(
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
                            if (photoUrl.startsWith('http') || kIsWeb) {
                              return Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultHeroBg(context));
                            } else {
                              return Image.file(File(photoUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultHeroBg(context));
                            }
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
                                    color: isActive ? AppColors.textPrimary : AppColors.textPrimary.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
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
                                  Text(
                                    user.name,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.4,
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
                              const SizedBox(height: 4),
                              Text(
                                '${user.age ?? '26'} • ${user.city != null && user.city!.isNotEmpty ? user.city : 'İstanbul'}',
                                style: TextStyle(
                                  color: AppColors.textPrimary.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    user.hideLastSeen ? Icons.visibility_off_rounded : Icons.circle,
                                    size: user.hideLastSeen ? 15 : 9,
                                    color: user.hideLastSeen ? AppColors.primaryVariant : const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.hideLastSeen ? 'Görünmez Mod (Çevrimiçi Gizli)' : 'Çevrimiçi',
                                    style: TextStyle(
                                      color: user.hideLastSeen ? AppColors.primaryVariant : const Color(0xFF4CAF50),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
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
                      Text(
                        'Tümünü Gör',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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

                // ── Action Buttons ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EditProfileScreen()),
                          ),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.4)),
                            ),
                            child: Center(
                              child: Text(
                                'Profili Düzenle',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.share_outlined,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ],
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            Theme.of(context).scaffoldBackgroundColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
                  event.imageUrl.startsWith('http')
                      ? Image.network(event.imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFF2A2A2A)))
                      : Image.asset(event.imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFF2A2A2A))),
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
