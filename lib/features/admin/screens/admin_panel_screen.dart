import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_event_service.dart';
import 'event_form_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yönetim Paneli', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.file_upload, color: AppColors.primary),
            tooltip: 'Excel\'den Yükle',
            onPressed: () async {
              fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
                type: fp.FileType.custom,
                allowedExtensions: ['xlsx'],
                withData: true,
              );

              if (result != null && result.files.single.bytes != null) {
                if (context.mounted) {
                  context.read<MockEventService>().importEventsFromExcel(result.files.single.bytes!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Etkinlikler başarıyla eklendi!')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Consumer<MockEventService>(
        builder: (context, eventService, child) {
          // Normalde gerçek senaryoda allEvents çekilir ama mock_event_service.dart private (_)
          // Tümü seçiliyken problem yaşamamak için bu ekrana girildiğinde kategori sıfırlanabilir.
          // Burada basitçe filteredEvents kullanıyorum.
          final events = eventService.getAdminEvents(); // Helper ekleyeceğim mock_event_service'e.
          
          if (events.isEmpty) {
             return Center(child: Text("Henüz hiç etkinlik yok.", style: TextStyle(color: AppColors.textSecondary)));
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
                              child: Icon(Icons.broken_image, color: AppColors.primary),
                            ),
                          )
                        : Image.asset(
                            event.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60, height: 60, color: Colors.black26,
                              child: Icon(Icons.broken_image, color: AppColors.primary),
                            ),
                          ),
                  ),
                  title: Text(event.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text("${event.category}\n${event.location}", style: TextStyle(color: AppColors.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Görünürlük", style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 24, // Keep it compact to fit the trailing slot easily
                            child: Transform.scale(
                              scale: 0.8, // Make the visual switch smaller so it doesn't clip tightly in the box
                              child: Switch(
                                value: event.isActive,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  eventService.toggleEventVisibility(event.id);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit, color: AppColors.secondary),
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
                              title: Text("Silmek istediğinize emin misiniz?", style: TextStyle(color: AppColors.textPrimary)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal", style: TextStyle(color: AppColors.textSecondary))),
                                ElevatedButton(
                                  onPressed: () {
                                    eventService.deleteEvent(event.id);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  child: Text("Sil"),
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
