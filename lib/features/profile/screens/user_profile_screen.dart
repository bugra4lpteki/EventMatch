import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/mock_match_service.dart';
import '../../events/widgets/vibe_check_widget.dart';
import '../../../core/widgets/report_block_sheet.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  final String? eventId;

  const UserProfileScreen({super.key, required this.user, this.eventId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _currentPhotoIndex = 0;
  bool _targetUserHideEvents = false;
  bool _targetUserPrivateProfile = false;

  @override
  void initState() {
    super.initState();
    _checkTargetUserPrivacy();
  }

  Future<void> _checkTargetUserPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final user = widget.user;

    final hideEventsPref = prefs.getBool('${user.id}_privacy_hide_events') ??
                           prefs.getBool('${user.name}_privacy_hide_events') ??
                           (user.username != null ? prefs.getBool('${user.username}_privacy_hide_events') : null) ??
                           user.hideEvents;

    final privateProfilePref = prefs.getBool('${user.id}_privacy_private_profile') ??
                               prefs.getBool('${user.name}_privacy_private_profile') ??
                               (user.username != null ? prefs.getBool('${user.username}_privacy_private_profile') : null) ??
                               user.isPrivateProfile;

    if (mounted) {
      setState(() {
        _targetUserHideEvents = hideEventsPref;
        _targetUserPrivateProfile = privateProfilePref;
      });
    }
  }

  Widget _defaultHeroBg(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.person, size: 100, color: AppColors.primary),
      ),
    );
  }

  Future<void> _launchUrl(String urlString, String prefix) async {
    String finalUrl = urlString.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      if (prefix.isNotEmpty && !finalUrl.contains(prefix.split('/').first)) {
        finalUrl = 'https://$prefix$finalUrl';
      } else {
        finalUrl = 'https://$finalUrl';
      }
    }
    await UrlLauncherHelper.launchURL(finalUrl);
  }

  Widget _getSocialIcon(String url) {
    final lUrl = url.toLowerCase();
    final iconColor = AppColors.primary;
    if (lUrl.contains('instagram')) return FaIcon(FontAwesomeIcons.instagram, color: iconColor, size: 20);
    if (lUrl.contains('twitter') || lUrl.contains('x.com')) return FaIcon(FontAwesomeIcons.xTwitter, color: iconColor, size: 20);
    if (lUrl.contains('linkedin')) return FaIcon(FontAwesomeIcons.linkedin, color: iconColor, size: 20);
    if (lUrl.contains('tiktok')) return FaIcon(FontAwesomeIcons.tiktok, color: iconColor, size: 20);
    if (lUrl.contains('facebook')) return FaIcon(FontAwesomeIcons.facebook, color: iconColor, size: 20);
    if (lUrl.contains('youtube')) return FaIcon(FontAwesomeIcons.youtube, color: iconColor, size: 20);
    if (lUrl.contains('spotify')) return FaIcon(FontAwesomeIcons.spotify, color: iconColor, size: 20);
    if (lUrl.contains('github')) return FaIcon(FontAwesomeIcons.github, color: iconColor, size: 20);
    return FaIcon(FontAwesomeIcons.link, color: iconColor, size: 20);
  }

  String _getSocialPrefix(String url) {
    final lUrl = url.toLowerCase();
    if (lUrl.contains('instagram')) return 'instagram.com/';
    if (lUrl.contains('twitter') || lUrl.contains('x.com')) return 'x.com/';
    if (lUrl.contains('linkedin')) return 'linkedin.com/in/';
    if (lUrl.contains('tiktok')) return 'tiktok.com/@';
    if (lUrl.contains('spotify')) return 'open.spotify.com/user/';
    return '';
  }

  Widget _buildEventList(BuildContext context, String title, List<String> eventIds, MockEventService eventService, {bool isHidden = false}) {
    if (isHidden) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text("🔒 Kullanıcı etkinlik katılımlarını gizledi.", style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontStyle: FontStyle.italic)),
        ],
      );
    }

    if (eventIds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text("Henüz etkinlik eklenmemiş.", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...eventIds.map((id) {
          final event = eventService.getEventById(id);
          if (event == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImageWidget(
                  imageUrl: event.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  memCacheWidth: 100,
                  memCacheHeight: 100,
                ),
              ),
              title: Text(event.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(event.category, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBadgeWidget(String badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getBadgeIcon(badge), color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            badge,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBadgeIcon(String badge) {
    switch (badge) {
      case 'Sahne Tozu Yutmuş':
        return Icons.theater_comedy;
      case 'Sinema Sever':
        return Icons.movie_filter;
      case 'Müzik Tutkunu':
        return Icons.music_note;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final matchService = context.watch<MockMatchService>();
    final user = widget.user;
    final isCurrentUser = (user.id == eventService.currentUser.id || user.name == eventService.currentUser.name);
    final hideEvents = isCurrentUser ? false : (_targetUserHideEvents || user.hideEvents);
    final isPrivateProfile = isCurrentUser ? false : (_targetUserPrivateProfile || user.isPrivateProfile);

    final hasSentReq = widget.eventId != null ? matchService.hasSentRequest(widget.eventId!, user.id) : false;

    final displayPhotos = user.avatarUrls.isNotEmpty
        ? user.avatarUrls
        : (user.avatarUrl.isNotEmpty ? [user.avatarUrl] : <String>[]);

    final ageStr = user.age != null && user.age!.isNotEmpty ? user.age : '24';
    final cityStr = user.city != null && user.city!.isNotEmpty ? user.city! : 'İstanbul';

    // Sadece kullanıcının gerçekten eklediği sosyal medya bağlantıları
    final socialLinks = user.socialLinks;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!isCurrentUser)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
              tooltip: 'Seçenekler & Şikayet',
              onPressed: () {
                ReportBlockSheet.showOptionsModal(
                  context,
                  userId: user.id,
                  userName: user.name,
                  onUserBlocked: () {
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Hero Profile Card ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                      // Page Indicators (-- ·)
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
                  ),
                ),
              ),
            ),
          ),

          // ── Content Sections ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name & Social Links Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$ageStr • $cityStr",
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sosyal Medya İkonları
                      Row(
                        children: socialLinks.take(4).map((link) {
                          if (link.isEmpty) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: IconButton(
                              icon: _getSocialIcon(link),
                              onPressed: () => _launchUrl(link, _getSocialPrefix(link)),
                              tooltip: link,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  if (user.points > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${user.points} PUAN',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isPrivateProfile) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gizli Profil',
                                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bu profil gizlidir. Detaylar ve etkinlik katılımları kısıtlanmıştır.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Rozetler (Badges)
                  if (user.badges.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.badges.map((b) => _buildBadgeWidget(b)).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Vibe Check Section
                  Builder(
                    builder: (context) {
                      final vibe = eventService.calculateVibe(user);
                      return VibeCheckWidget(
                        score: vibe['score'],
                        commonalities: vibe['commonalities'],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Hakkımda Section
                  if (user.aboutMe != null && user.aboutMe!.isNotEmpty && !isPrivateProfile) ...[
                    Text(
                      "Hakkımda",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.aboutMe!,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // İlgi Alanları Section
                  Text(
                    "İlgi Alanları",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (user.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      "Henüz ilgi alanı belirtilmemiş.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  const SizedBox(height: 28),

                  // Etkinlik Listeleri
                  _buildEventList(context, "Gitmeyi Düşündüğü Etkinlikler", user.plannedEvents, eventService, isHidden: hideEvents || isPrivateProfile),
                  const SizedBox(height: 24),
                  _buildEventList(context, "Daha Önce Gittiği Etkinlikler", user.pastEvents, eventService, isHidden: hideEvents || isPrivateProfile),

                  if (widget.eventId != null) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: hasSentReq
                            ? null
                            : () {
                                matchService.sendRequest(widget.eventId!, user);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Eşleşme isteği gönderildi!"),
                                    backgroundColor: AppColors.secondary,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasSentReq ? AppColors.surface : AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                        child: Text(
                          hasSentReq ? 'İSTEK GÖNDERİLDİ' : 'TANIŞMAK İSTER MİSİN? (İSTEK GÖNDER)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: hasSentReq ? AppColors.textSecondary : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
