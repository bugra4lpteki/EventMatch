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
        cacheExtent: 600, // Pre-cache offscreen items to prevent scroll jank
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
              // Popüler Etkinlikler Carousel & Filtre Çipleri (Arama esnasında gizle, ekranı arama sonuçlarına aç)
              if (_searchController.text.trim().isEmpty) ...[
                RepaintBoundary(
                  child: Consumer<MockEventService>(
                    builder: (context, eventService, child) {
                      final allEvents = eventService.getAdminEvents();
                      final sortedEvents = List<EventModel>.from(allEvents)
                        ..sort((a, b) => b.attendees.length.compareTo(a.attendees.length));
                      final popularEvents = sortedEvents.take(5).toList();
                      return PopularEventsCarousel(events: popularEvents);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Filter Chips
                RepaintBoundary(
                  child: SizedBox(
                    height: 60,
                    child: Consumer<MockEventService>(
                      builder: (context, eventService, child) {
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          cacheExtent: 250,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: eventService.categories.length,
                          itemBuilder: (context, index) {
                            final category = eventService.categories[index];
                            final isSelected = eventService.selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
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
                ),
              ] else ...[
                Consumer<MockEventService>(
                  builder: (context, eventService, child) {
                    final count = eventService.filteredEvents.length;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          Icon(Icons.manage_search_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '"${_searchController.text.trim()}" için $count Etkinlik Bulundu',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        // Lazy-loaded Event List (Zero-lag rendering with RepaintBoundary & automatic keep-alives)
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
                      key: ValueKey('event_card_${events[index].id}'),
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
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: true,
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

  void _showCitySearchPicker(BuildContext context, MockEventService eventService, StateSetter setModalState) {
    String searchFilter = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filteredCities = MockEventService.allTurkishCities.where((c) {
              if (searchFilter.isEmpty) return true;
              return c.toLowerCase().contains(searchFilter.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Şehir Seçiniz (81 İl)',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) => setPickerState(() => searchFilter = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Şehir ara... (Örn: Eskişehir, Muğla, Trabzon)',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = filteredCities[index];
                        final isSelected = eventService.selectedCity == city;
                        return ListTile(
                          title: Text(
                            city,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            eventService.setCity(city);
                            setModalState(() {});
                            Navigator.pop(context);
                          },
                        );
                      },
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

  void _showFilterDialog(BuildContext context) {
    final eventService = context.read<MockEventService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Şehir Seçimi',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () => _showCitySearchPicker(context, eventService, setModalState),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '81 İl İçinden Ara',
                                style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...eventService.cities.map((city) {
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
                      }),
                      ActionChip(
                        avatar: Icon(Icons.add_location_alt_rounded, size: 14, color: AppColors.primary),
                        label: Text('Diğer Şehir...', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                        onPressed: () => _showCitySearchPicker(context, eventService, setModalState),
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
