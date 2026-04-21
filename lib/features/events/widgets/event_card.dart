import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/event_model.dart';
import '../services/mock_event_service.dart';
import 'candy_machine_avatars.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = "${event.dateTime.day.toString().padLeft(2, '0')}.${event.dateTime.month.toString().padLeft(2, '0')}.${event.dateTime.year} - ${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'event_image_${event.id}',
                    child: event.imageUrl.startsWith('http')
                        ? Image.network(
                            event.imageUrl,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 140,
                              color: AppColors.surface,
                              child: Center(
                                child: Icon(Icons.broken_image, color: AppColors.primary, size: 32),
                              ),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Shimmer.fromColors(
                                baseColor: AppColors.surface,
                                highlightColor: AppColors.primary.withOpacity(0.3),
                                child: Container(height: 140, color: Colors.white),
                              );
                            },
                          )
                        : Image.asset(
                            event.imageUrl,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 140,
                              color: AppColors.surface,
                              child: Center(
                                child: Icon(Icons.broken_image, color: AppColors.primary, size: 32),
                              ),
                            ),
                          ),
                  ),
                  if (event.isPopular)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'POPÜLER',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: Row(
                      children: [
                        Icon(Icons.flash_on, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          event.atmosphere,
                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  // Attendee "Candy Machine" Avatars - Animated
                  Positioned(
                    top: 10,
                    left: 140,
                    right: 10,
                    bottom: 35,
                    child: CandyMachineAvatars(attendees: event.attendees),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                              ),
                              child: Text(
                                event.category,
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
