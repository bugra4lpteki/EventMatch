import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../models/event_model.dart';
import '../screens/event_detail_screen.dart';
import '../services/mock_event_service.dart';
import '../services/spotify_service.dart';

/// Performance-optimized Event Card with Spotify Artist Banner support.
/// Music/concert events show the artist's Spotify/Deezer banner image.
/// Non-music events fall back to event.imageUrl.
class EventCard extends StatefulWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  final SpotifyService _spotifyService = SpotifyService();
  late Future<String?> _bannerFuture;

  bool get _isMusicEvent {
    final cat = widget.event.category.toLowerCase().trim();
    final title = widget.event.title.toLowerCase().trim();
    if (cat.contains('tiyatro') ||
        cat.contains('theatre') ||
        cat.contains('arts') ||
        cat.contains('stand-up') ||
        cat.contains('standup') ||
        cat.contains('komedi') ||
        cat.contains('comedy') ||
        cat.contains('sahne') ||
        cat.contains('spor') ||
        cat.contains('sport') ||
        cat.contains('sergi') ||
        cat.contains('atölye') ||
        cat.contains('workshop') ||
        cat.contains('sinema') ||
        cat.contains('cinema') ||
        title.contains('stand-up') ||
        title.contains('stand up') ||
        title.contains('tiyatro') ||
        title.contains('gösteri') ||
        title.contains('oyun') ||
        title.contains('tek kişilik')) {
      return false;
    }
    return cat.contains('konser') ||
        cat.contains('concert') ||
        cat.contains('müzik') ||
        cat.contains('music') ||
        cat.contains('akustik') ||
        cat.contains('festival');
  }

  @override
  void initState() {
    super.initState();
    _bannerFuture = _isMusicEvent
        ? _spotifyService.getArtistImageUrl(
            widget.event.title,
            category: widget.event.category,
          )
        : Future.value(null);
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('konser') || lower.contains('müzik') || lower.contains('music')) {
      return Icons.music_note_rounded;
    } else if (lower.contains('tiyatro') || lower.contains('sahne') || lower.contains('arts')) {
      return Icons.theater_comedy_rounded;
    } else if (lower.contains('stand-up') || lower.contains('komedi') || lower.contains('comedy')) {
      return Icons.emoji_emotions_rounded;
    } else if (lower.contains('spor') || lower.contains('sports')) {
      return Icons.sports_soccer_rounded;
    }
    return Icons.event_rounded;
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    final formattedDate =
        '${widget.event.dateTime.day} ${months[widget.event.dateTime.month - 1]} ${widget.event.dateTime.year}';
    final ticketUrlStr = widget.event.effectiveTicketUrl;

    // Spotify mobile artist banner: ~16:9 landscape crop, 230px height
    const double bannerHeight = 230;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(event: widget.event),
                ),
              );
            },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner Image ── Spotify artist photo for music events ──
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: SizedBox(
                      height: bannerHeight,
                      width: double.infinity,
                      child: FutureBuilder<String?>(
                        future: _bannerFuture,
                        builder: (context, snapshot) {
                          // Use Spotify/Deezer artist image when available;
                          // otherwise fall back to the event's own imageUrl.
                          final resolvedUrl =
                              (snapshot.connectionState == ConnectionState.done &&
                                      snapshot.data != null &&
                                      snapshot.data!.isNotEmpty)
                                  ? snapshot.data!
                                  : widget.event.imageUrl;

                          return Hero(
                            tag: 'event_image_${widget.event.id}',
                            child: AppImageWidget(
                              imageUrl: resolvedUrl,
                              fit: BoxFit.cover,
                              // Top-center alignment: frames artist face (Spotify mobile banner style)
                              alignment: const Alignment(0, -0.2),
                              height: bannerHeight,
                              width: double.infinity,
                              // ~2× retina cache width for a 390pt iPhone 16 screen
                              memCacheWidth: 780,
                              // 16:9 cache height
                              memCacheHeight: 440,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Gradient Shadow Overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.28),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.82),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.38, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Popular / High Match / Upcoming Badge
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _LiveEventBadge(event: widget.event),
                  ),
                ],
              ),
              // ── Content Info Panel ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getCategoryIcon(widget.event.category),
                              size: 12, color: AppColors.primaryVariant),
                          const SizedBox(width: 5),
                          Text(
                            widget.event.category,
                            style: TextStyle(
                              color: AppColors.primaryVariant,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      widget.event.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Date & Location
                    Text(
                      '$formattedDate • ${widget.event.location}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Action Footer Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LiveAttendeesRow(event: widget.event),
                        GestureDetector(
                          onTap: () async {
                            if (ticketUrlStr.isNotEmpty) {
                              await UrlLauncherHelper.launchURL(ticketUrlStr);
                            }
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Biletler',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded,
                                    size: 15, color: Colors.white),
                              ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Live attendees row (reactive via Provider)
// ─────────────────────────────────────────────────────────────
class _LiveAttendeesRow extends StatelessWidget {
  final EventModel event;
  const _LiveAttendeesRow({required this.event});

  @override
  Widget build(BuildContext context) {
    MockEventService? eventService;
    try {
      eventService = Provider.of<MockEventService>(context, listen: true);
    } catch (_) {
      eventService = null;
    }

    final liveEvent = eventService?.getEventById(event.id) ?? event;
    final isAttending = eventService?.isUserAttending(liveEvent.id) ?? false;
    final count = liveEvent.attendees.length;

    final String attendeesText;
    final IconData iconData;
    final Color textColor;

    if (isAttending) {
      iconData = Icons.check_circle_rounded;
      textColor = AppColors.success;
      attendeesText = count <= 1 ? 'Sen katılıyorsun' : 'Sen + ${count - 1} kişi katılıyor';
    } else {
      textColor = AppColors.accent;
      iconData = Icons.people_outline;
      attendeesText = count > 0 ? '$count kişi katılıyor' : 'İlk katılan sen ol';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconData, color: textColor, size: 15),
        const SizedBox(width: 5),
        Text(
          attendeesText,
          style: TextStyle(
            color: textColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Live badge (reactive via Provider)
// ─────────────────────────────────────────────────────────────
class _LiveEventBadge extends StatelessWidget {
  final EventModel event;
  const _LiveEventBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    MockEventService? eventService;
    try {
      eventService = Provider.of<MockEventService>(context, listen: true);
    } catch (_) {
      eventService = null;
    }

    final liveEvent = eventService?.getEventById(event.id) ?? event;
    final isPop = liveEvent.attendees.length >= 5 ||
        (liveEvent.isPopular && liveEvent.attendees.length >= 3);
    final isHighMatch = !isPop && liveEvent.attendees.length >= 2;
    final daysUntil = liveEvent.dateTime.difference(DateTime.now()).inDays;
    final isUpcoming = !isPop && !isHighMatch && daysUntil >= 0 && daysUntil <= 4;

    final String badgeText;
    final LinearGradient badgeGradient;
    final Color shadowColor;

    if (isPop) {
      badgeText = '🔥 POPÜLER';
      badgeGradient = AppColors.goldGradient;
      shadowColor = const Color(0xFFF59E0B);
    } else if (isHighMatch) {
      badgeText = '💖 YÜKSEK EŞLEŞME';
      badgeGradient = AppColors.primaryGradient;
      shadowColor = AppColors.primary;
    } else if (isUpcoming) {
      badgeText = '⚡ YAKINDA';
      badgeGradient = AppColors.accentGradient;
      shadowColor = const Color(0xFF06B6D4);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
