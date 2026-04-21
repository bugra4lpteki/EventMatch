import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/mock_event_service.dart';
import '../services/mock_match_service.dart';
import '../services/notification_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../screens/venue_chat_screen.dart';
import '../widgets/carpool_sheet.dart';

class EventDetailScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr = "${event.dateTime.day.toString().padLeft(2, '0')}.${event.dateTime.month.toString().padLeft(2, '0')}.${event.dateTime.year} - ${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await NotificationService.scheduleEventReminders(event);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hatırlatıcılar kuruldu! (09:00, 30dk kala ve tam saatinde)'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
            ],
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
                          child: Center(
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
                          child: Center(
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
                    style: TextStyle(
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
                  InkWell(
                    onTap: () async {
                      if (event.latitude != null && event.longitude != null) {
                        final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(event.location, style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(dateStr, style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text("Hakkında", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(event.description, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
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
                              SnackBar(
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

                  const SizedBox(height: 16),
                  // Birlikte Git (Carpool) Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CarpoolSheet(event: event),
                        );
                      },
                      icon: Icon(Icons.directions_car_outlined, color: AppColors.primary),
                      label: Text(
                        'BİRLİKTE GİT (ULAŞIM)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Check-in and Chat Section
                  Consumer<MockEventService>(
                    builder: (context, eventService, child) {
                      final isAttending = eventService.isUserAttending(event.id);
                      final isCheckedIn = eventService.isUserCheckedIn(event.id);

                      if (!isAttending) return const SizedBox.shrink();

                      return Column(
                        children: [
                          _buildGlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isCheckedIn ? Colors.green.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCheckedIn ? Icons.location_on : Icons.location_on_outlined,
                                        color: isCheckedIn ? Colors.green : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCheckedIn ? 'Mekandasın!' : 'Mekanda mısın?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            isCheckedIn ? 'Diğerleriyle sohbete başla.' : 'Check-in yap, rozetini kap!',
                                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isCheckedIn)
                                      ElevatedButton(
                                        onPressed: () {
                                          HapticFeedback.heavyImpact();
                                          eventService.checkIn(event.id);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('CHECK-IN'),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green),
                                        ),
                                        child: const Text('MEKANDA', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                if (isCheckedIn) ...[
                                  const Divider(color: Colors.white10, height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => VenueChatScreen(event: event)),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      label: const Text('MEKAN SOHBETİNE KATIL'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: BorderSide(color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),

                  
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
                           child: Center(
                             child: Text("Katılımcıları görmek için etkinliğe katılın.", 
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary)),
                           ),
                         );
                      }

                      if (attendees.isEmpty) {
                        return Center(child: Text("Henüz kimse katılmadı. İlk sen ol!", style: TextStyle(color: AppColors.textSecondary)));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: attendees.length,
                        itemBuilder: (context, index) {
                          final user = attendees[index];
                          final hasSentReq = matchService.hasSentRequest(event.id, user.id);
                          final isAtVenue = (index % 2 == 0); 
                          
                          return ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(
                                    user: user,
                                    eventId: event.id,
                                  ),
                                ),
                              );
                            },
                            contentPadding: EdgeInsets.zero,
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.surface,
                                  radius: 24,
                                  child: ClipOval(
                                    child: user.avatarUrl.startsWith('http')
                                      ? Image.network(
                                          user.avatarUrl,
                                          width: 48, height: 48, fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: AppColors.primary),
                                        )
                                      : Image.asset(
                                          user.avatarUrl,
                                          width: 48, height: 48, fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: AppColors.primary),
                                        ),
                                  ),
                                ),
                                if (isAtVenue)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.background, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Text(user.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                if (isAtVenue) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('MEKANDA', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            trailing: hasSentReq 
                            ? OutlinedButton(
                                onPressed: null,
                                child: Text("İstek Gönderildi", style: TextStyle(color: AppColors.textSecondary)),
                              )
                            : Icon(Icons.chevron_right, color: AppColors.primary),
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

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}
