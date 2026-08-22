import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../models/event_model.dart';
import '../screens/event_detail_screen.dart';

/// Performance-optimized Event Card with RepaintBoundary and Cached/Memory-bounded Image decoding.
class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

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
    final formattedDate = '${event.dateTime.day} ${months[event.dateTime.month - 1]} ${event.dateTime.year}';
    final ticketUrlStr = event.effectiveTicketUrl;

    // RepaintBoundary isolates card rasterization during ListView/CustomScrollView fling
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(event: event),
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
              // Banner Image with memory-constrained caching
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: SizedBox(
                      height: 235,
                      width: double.infinity,
                      child: Hero(
                        tag: 'event_image_${event.id}',
                        child: AppImageWidget(
                          imageUrl: event.imageUrl,
                          fit: BoxFit.cover,
                          height: 235,
                          width: double.infinity,
                          memCacheWidth: 640,
                          memCacheHeight: 360,
                        ),
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
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Top Left: Provider Badge (Biletix, Biletinial, Bubilet)
                  if (event.ticketProvider != null && event.ticketProvider!.isNotEmpty)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: event.ticketProvider!.toLowerCase().contains('biletinial')
                              ? const Color(0xFFE11D48)
                              : event.ticketProvider!.toLowerCase().contains('bubilet')
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          event.ticketProvider!.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  // Popular / High Match / Upcoming Badge
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Builder(
                      builder: (context) {
                        final isPop = event.attendees.length >= 5 || (event.isPopular && event.attendees.length >= 3);
                        final isHighMatch = !isPop && event.attendees.length >= 2;
                        final daysUntil = event.dateTime.difference(DateTime.now()).inDays;
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
                          badgeText = '✨ ETKİNLİK';
                          badgeGradient = const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          );
                          shadowColor = const Color(0xFF6366F1);
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
                      },
                    ),
                  ),
                ],
              ),
              // Content Info Panel
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
                          Icon(_getCategoryIcon(event.category), size: 12, color: AppColors.primaryVariant),
                          const SizedBox(width: 5),
                          Text(
                            event.category,
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
                    // Title Header
                    Text(
                      event.title,
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
                      '$formattedDate • ${event.location}',
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
                        Row(
                          children: [
                            Icon(Icons.people_outline, color: AppColors.accent, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              event.attendees.isNotEmpty
                                  ? '${event.attendees.length} kişi katılıyor'
                                  : 'İlk katılan sen ol',
                              style: TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () async {
                            if (ticketUrlStr.isNotEmpty) {
                              await UrlLauncherHelper.launchURL(ticketUrlStr);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  event.ticketProvider != null && event.ticketProvider!.isNotEmpty
                                      ? '${event.ticketProvider} Bilet'
                                      : 'Bilet Al',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, size: 15, color: Colors.white),
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
