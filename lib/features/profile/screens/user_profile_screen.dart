import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/mock_match_service.dart';
import '../../events/widgets/vibe_check_widget.dart';

class UserProfileScreen extends StatelessWidget {
  final UserModel user;
  final String? eventId; // Optional: If coming from an event, allow sending a match request for this event

  const UserProfileScreen({super.key, required this.user, this.eventId});

  Widget _buildImage(String url) {
    if (url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, size: 60, color: AppColors.primary));
    } else if (url.startsWith('/')) { // Yerel dosya yolu (Image Picker'dan gelen)
      return Image.file(File(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, size: 60, color: AppColors.primary));
    }
    return Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, size: 60, color: AppColors.primary));
  }

  Widget _buildEventList(BuildContext context, String title, List<String> eventIds, MockEventService eventService) {
    if (eventIds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text("Henüz etkinlik eklenmemiş.", style: TextStyle(color: AppColors.textSecondary)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        ...eventIds.map((id) {
          final event = eventService.getEventById(id);
          if (event == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: event.imageUrl.startsWith('http')
                    ? Image.network(event.imageUrl, width: 48, height: 48, fit: BoxFit.cover)
                    : Image.asset(event.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
              ),
              title: Text(event.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text(event.category, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.read<MockEventService>();
    final matchService = context.read<MockMatchService>();
    final hasSentReq = eventId != null ? matchService.hasSentRequest(eventId!, user.id) : false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: user.avatarUrl.isNotEmpty
                      ? _buildImage(user.avatarUrl)
                      : Icon(Icons.person, size: 60, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                "${user.name}${user.age != null && user.age!.isNotEmpty ? ', ${user.age}' : ''}",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "${user.points} PUAN",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (user.badges.isNotEmpty)
              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: user.badges.map((badge) => _buildBadgeWidget(badge)).toList(),
                ),
              ),
            const SizedBox(height: 24),
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
            if (user.aboutMe != null && user.aboutMe!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("Hakkımda", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                user.aboutMe!,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
            const SizedBox(height: 24),
            Text("İlgi Alanları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (user.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.tags.map((tag) {
                  return Chip(
                    label: Text(tag, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.surface,
                    side: BorderSide.none,
                  );
                }).toList(),
              )
            else
              Text("Henüz ilgi alanı belirtilmemiş.", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            
            _buildEventList(context, "Gitmeyi Düşündüğü Etkinlikler", user.plannedEvents, eventService),
            const SizedBox(height: 24),
            _buildEventList(context, "Daha Önce Gittiği Etkinlikler", user.pastEvents, eventService),

            if (eventId != null) ...[
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: hasSentReq
                      ? null
                      : () {
                          matchService.sendRequest(eventId!, user);
                          Navigator.pop(context); // Go back after sending request
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Eşleşme isteği gönderildi!"), backgroundColor: AppColors.secondary),
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
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeWidget(String badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getBadgeIcon(badge), color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            badge,
            style: TextStyle(
              color: AppColors.textPrimary,
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
}
