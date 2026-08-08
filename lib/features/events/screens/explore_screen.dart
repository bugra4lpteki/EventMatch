import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_event_service.dart';
import '../widgets/event_card.dart';
import '../widgets/popular_events_carousel.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';

import 'dart:ui';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // Modern Arama Çubuğu
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context.read<MockEventService>().setSearchQuery(value);
                    },
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Etkinlik, sanatçı veya mekan ara...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                context.read<MockEventService>().setSearchQuery('');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 14),
                              ),
                            ),
                          GestureDetector(
                            onTap: () => _showFilterDialog(context),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                              ),
                              child: Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
              // Popüler Etkinlikler Carousel
              Consumer<MockEventService>(
                builder: (context, eventService, child) {
                  final allEvents = eventService.getAdminEvents();
                  final sortedEvents = List<EventModel>.from(allEvents)
                    ..sort((a, b) => b.attendees.length.compareTo(a.attendees.length));
                  final popularEvents = sortedEvents.take(5).toList();
                  return PopularEventsCarousel(events: popularEvents);
                },
              ),
              const SizedBox(height: 8),
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
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
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
                            shadowColor: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Lazy-loaded Event List (Zero-lag rendering)
        Consumer<MockEventService>(
          builder: (context, eventService, child) {
            final events = eventService.filteredEvents;
            if (events.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      "Bu kategoride etkinlik bulunamadı.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                  childCount: events.length,
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    ),
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
                          eventService.setCity('Tüm Şehirler');
                          Navigator.pop(context);
                        },
                        child: Text('Sıfırla', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Şehir Seçimi',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: eventService.cities.map((city) {
                      final isSelected = eventService.selectedCity == city;
                      return ChoiceChip(
                        label: Text(city),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            eventService.setCity(city);
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
