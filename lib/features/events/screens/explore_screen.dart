import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_event_service.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                return const Center(child: Text("Bu kategoride etkinlik bulunamadı.", style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return EventCard(
                    event: events[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(event: events[index]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
