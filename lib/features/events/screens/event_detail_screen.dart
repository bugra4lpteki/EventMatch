import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/mock_event_service.dart';
import '../services/mock_match_service.dart';

class EventDetailScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  void _showRequestSheet(BuildContext context, UserModel user, String eventId, bool hasSentReq, MockMatchService matchService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.surface,
                child: ClipOval(
                  child: user.avatarUrl.startsWith('http')
                      ? Image.network(user.avatarUrl, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: AppColors.primary))
                      : Image.asset(user.avatarUrl, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "${user.name}${user.age != null && user.age!.isNotEmpty ? ', ${user.age}' : ''}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              if (user.aboutMe != null && user.aboutMe!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  user.aboutMe!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: hasSentReq
                      ? null
                      : () {
                          matchService.sendRequest(eventId, user);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Eşleşme isteği gönderildi!"), backgroundColor: AppColors.secondary),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSentReq ? AppColors.surface : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = "${event.dateTime.day.toString().padLeft(2, '0')}.${event.dateTime.month.toString().padLeft(2, '0')}.${event.dateTime.year} - ${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event_image_${event.id}',
                child: event.imageUrl.startsWith('http')
                    ? Image.network(
                        event.imageUrl,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.3),
                        colorBlendMode: BlendMode.darken,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: AppColors.primary, size: 64),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Shimmer.fromColors(
                            baseColor: AppColors.surface,
                            highlightColor: AppColors.primary.withOpacity(0.3),
                            child: Container(color: Colors.white),
                          );
                        },
                      )
                    : Image.asset(
                        event.imageUrl,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.3),
                        colorBlendMode: BlendMode.darken,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: AppColors.primary, size: 64),
                          ),
                        ),
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            child: child,
                            opacity: frame == null ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 500),
                          );
                        },
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(event.location, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(dateStr, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Hakkında", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(event.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 40),
                  
                  // Ben de Buradayım Button
                  Consumer<MockEventService>(
                    builder: (context, eventService, child) {
                      final isAttending = eventService.isUserAttending(event.id);
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isAttending ? null : () {
                            HapticFeedback.lightImpact();
                            eventService.joinEvent(event.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Etkinliğe katıldın! Artık listedesin.'),
                                backgroundColor: AppColors.primary,
                              )
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAttending ? AppColors.surface : AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            disabledBackgroundColor: AppColors.surface,
                            shadowColor: isAttending ? Colors.transparent : AppColors.primary,
                            elevation: isAttending ? 0 : 10,
                          ),
                          child: Text(
                            isAttending ? 'BURADASIN' : 'BEN DE BURADAYIM!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isAttending ? AppColors.textSecondary : Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  const Text("Takılmak İsteyenler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  
                  // Attendees List
                  Consumer2<MockEventService, MockMatchService>(
                    builder: (context, eventService, matchService, child) {
                      final currentEvent = eventService.getEventById(event.id) ?? event;
                      final attendees = currentEvent.attendees.where((u) => u.id != eventService.currentUser.id).toList();

                      if (!eventService.isUserAttending(event.id)) {
                         return Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: AppColors.surface.withOpacity(0.5),
                             borderRadius: BorderRadius.circular(16),
                           ),
                           child: const Center(
                             child: Text("Takılmak isteyenleri görmek için etkinliğe katılın.", 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary)),
                           ),
                         );
                      }

                      if (attendees.isEmpty) {
                        return const Center(child: Text("Henüz kimse katılmadı. İlk sen ol!", style: TextStyle(color: AppColors.textSecondary)));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: attendees.length,
                        itemBuilder: (context, index) {
                          final user = attendees[index];
                          final hasSentReq = matchService.hasSentRequest(event.id, user.id);
                          
                          return ListTile(
                            onTap: () {
                              _showRequestSheet(context, user, event.id, hasSentReq, matchService);
                            },
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surface,
                              radius: 24,
                              child: ClipOval(
                                child: user.avatarUrl.startsWith('http')
                                  ? Image.network(
                                      user.avatarUrl,
                                      width: 48, height: 48, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
                                    )
                                  : Image.asset(
                                      user.avatarUrl,
                                      width: 48, height: 48, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
                                    ),
                              ),
                            ),
                            title: Text(user.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                            trailing: hasSentReq 
                            ? const OutlinedButton(
                                onPressed: null,
                                child: Text("İstek Gönderildi", style: TextStyle(color: AppColors.textSecondary)),
                              )
                            : const Icon(Icons.chevron_right, color: AppColors.primary),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
