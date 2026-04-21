import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_event_service.dart';
import '../widgets/event_card.dart';
import '../widgets/popular_events_carousel.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) {
              context.read<MockEventService>().setSearchQuery(value);
            },
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Etkinlik veya mekan ara...',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: Icon(Icons.search, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(Icons.tune, color: AppColors.primary),
                onPressed: () => _showFilterDialog(context),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        // Popüler Etkinlikler Carousel
        Consumer<MockEventService>(
          builder: (context, eventService, child) {
            final allEvents = eventService.getAdminEvents();
            // Katılımcı sayısına göre sıralayıp en çok katılımcısı olan 5'ini alalım
            final sortedEvents = List<EventModel>.from(allEvents)
              ..sort((a, b) => b.attendees.length.compareTo(a.attendees.length));
            final popularEvents = sortedEvents.take(5).toList();
            return PopularEventsCarousel(events: popularEvents);
          },
        ),
        const SizedBox(height: 8),
        // Activity Feed (Sosyal Akış)
        SizedBox(
          height: 60,
          child: Consumer<MockEventService>(
            builder: (context, eventService, child) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                itemCount: eventService.activityFeed.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9), // Glassmorphism base
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1), // Neon border hint
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (eventService.activityFeed[index].contains('mekanda'))
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                          Text(
                            eventService.activityFeed[index],
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Filter Chips
        SizedBox(
          height: 60,
          child: Consumer<MockEventService>(
            builder: (context, eventService, child) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: eventService.categories.length,
                itemBuilder: (context, index) {
                  final category = eventService.categories[index];
                  final isSelected = eventService.selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) eventService.setCategory(category);
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 1.5,
                      ),
                      elevation: isSelected ? 4 : 0,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Event List
        Expanded(
          child: Consumer<MockEventService>(
            builder: (context, eventService, child) {
              final events = eventService.filteredEvents;
              if (events.isEmpty) {
                return Center(child: Text("Bu kategoride etkinlik bulunamadı.", style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder(
                    duration: Duration(milliseconds: 400 + (index * 100)),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: EventCard(
                      event: events[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailScreen(event: events[index]),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFilterDialog(BuildContext context) {
    final eventService = context.read<MockEventService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtrele',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          eventService.setCategory('Tümü');
                          Navigator.pop(context);
                        },
                        child: Text('Sıfırla', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kategoriler',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: eventService.categories.map((cat) {
                      final isSelected = eventService.selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            eventService.setCategory(cat);
                            setModalState(() {});
                          }
                        },
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        side: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('UYGULA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
