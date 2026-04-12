import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import 'event_form_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim Paneli', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
      body: Consumer<MockEventService>(
        builder: (context, eventService, child) {
          // Normalde gerçek senaryoda allEvents çekilir ama mock_event_service.dart private (_)
          // Tümü seçiliyken problem yaşamamak için bu ekrana girildiğinde kategori sıfırlanabilir.
          // Burada basitçe filteredEvents kullanıyorum.
          final events = eventService.getAdminEvents(); // Helper ekleyeceğim mock_event_service'e.
          
          if (events.isEmpty) {
             return const Center(child: Text("Henüz hiç etkinlik yok.", style: TextStyle(color: AppColors.textSecondary)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: event.imageUrl.startsWith('http')
                        ? Image.network(
                            event.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60, height: 60, color: Colors.black26,
                              child: const Icon(Icons.broken_image, color: AppColors.primary),
                            ),
                          )
                        : Image.asset(
                            event.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60, height: 60, color: Colors.black26,
                              child: const Icon(Icons.broken_image, color: AppColors.primary),
                            ),
                          ),
                  ),
                  title: Text(event.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text("${event.category}\n${event.location}", style: const TextStyle(color: AppColors.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.secondary),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => EventFormScreen(event: event)
                          ));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          showDialog(
                            context: context, 
                            builder: (context) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: const Text("Silmek istediğinize emin misiniz?", style: TextStyle(color: AppColors.textPrimary)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal", style: TextStyle(color: AppColors.textSecondary))),
                                ElevatedButton(
                                  onPressed: () {
                                    eventService.deleteEvent(event.id);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  child: const Text("Sil"),
                                ),
                              ],
                            ));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const EventFormScreen()));
        },
      ),
    );
  }
}
