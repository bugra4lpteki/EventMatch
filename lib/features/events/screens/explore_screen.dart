import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_event_service.dart';
import '../widgets/event_card.dart';
import '../widgets/popular_events_carousel.dart';
import 'event_detail_screen.dart';
import '../../admin/screens/admin_login_screen.dart';
import 'package:flutter/services.dart';

import 'dart:ui';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isSearchFocused = _searchFocusNode.hasFocus;
        });
      }
    });
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _checkSecretAdminSearch(String value) {
    final query = value.trim().toLowerCase();
    if (query == '#admin' || query == '#panel' || query == '*999#' || query == '#vitrin') {
      _searchController.clear();
      context.read<MockEventService>().setSearchQuery('');
      FocusScope.of(context).unfocus();
      HapticFeedback.heavyImpact();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  void _onSearchSubmit(String value) {
    _checkSecretAdminSearch(value);
    _searchFocusNode.unfocus();
    HapticFeedback.mediumImpact();
    context.read<MockEventService>().setSearchQuery(value.trim());
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildActiveFilterTag({required String label, required VoidCallback onClear}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primaryVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(Icons.close_rounded, size: 14, color: AppColors.primaryVariant),
            ),
          ),
        ],
      ),
    );
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
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await context.read<MockEventService>().fetchEvents();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          cacheExtent: 600, // Pre-cache offscreen items to prevent scroll jank
          slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              // Estetik & Modern Arama Çubuğu ve Arama Butonu
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _isSearchFocused
                        ? AppColors.surface.withValues(alpha: 0.95)
                        : AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSearchFocused
                          ? AppColors.primary.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.12),
                      width: _isSearchFocused ? 1.6 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSearchFocused
                            ? AppColors.primary.withValues(alpha: 0.28)
                            : Colors.black.withValues(alpha: 0.18),
                        blurRadius: _isSearchFocused ? 20 : 12,
                        spreadRadius: _isSearchFocused ? 1 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Modern Sol Arama Butonu (Glow & Gradient)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (!_searchFocusNode.hasFocus) {
                            _searchFocusNode.requestFocus();
                          } else if (_searchController.text.trim().isNotEmpty) {
                            _onSearchSubmit(_searchController.text);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(left: 7, right: 6),
                          decoration: BoxDecoration(
                            gradient: (_isSearchFocused || _searchController.text.isNotEmpty)
                                ? AppColors.primaryGradient
                                : LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.22),
                                      AppColors.secondary.withValues(alpha: 0.12),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: (_isSearchFocused || _searchController.text.isNotEmpty)
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.search_rounded,
                              color: (_isSearchFocused || _searchController.text.isNotEmpty)
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      // Arama Giriş Alanı
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) {
                            _checkSecretAdminSearch(value);
                            context.read<MockEventService>().setSearchQuery(value);
                          },
                          onSubmitted: _onSearchSubmit,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Etkinlik, sanatçı veya mekan ara...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.65),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          ),
                        ),
                      ),
                      // Sağ Aksiyonlar (Temizleme + Arama Aksiyon Butonu + Filtre)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty) ...[
                            // Temizleme Butonu (X)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _searchController.clear();
                                context.read<MockEventService>().setSearchQuery('');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 14),
                              ),
                            ),
                            // "Ara" Butonu (Modern Gradient Pill)
                            GestureDetector(
                              onTap: () => _onSearchSubmit(_searchController.text),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Ara',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 13),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Filtreleme Butonu
                          Consumer<MockEventService>(
                            builder: (context, eventService, child) {
                              final bool hasActiveFilter = (eventService.selectedCity != 'Tüm Şehirler' && eventService.selectedCity != 'Tümü') ||
                                  eventService.selectedCategory != 'Tümü' ||
                                  eventService.selectedDateFilter != 'Tümü';

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showFilterDialog(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 7),
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: hasActiveFilter
                                        ? AppColors.primary.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: hasActiveFilter
                                          ? AppColors.primary
                                          : Colors.white.withValues(alpha: 0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        color: hasActiveFilter ? AppColors.primaryVariant : AppColors.textSecondary,
                                        size: 18,
                                      ),
                                      if (hasActiveFilter)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: AppColors.secondary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.secondary.withValues(alpha: 0.8),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Popüler Etkinlikler Carousel & Filtre Çipleri (Arama esnasında gizle, ekranı arama sonuçlarına aç)
              if (_searchController.text.trim().isEmpty) ...[
                RepaintBoundary(
                  child: Consumer<MockEventService>(
                    builder: (context, eventService, child) {
                      final carouselEvents = eventService.getCarouselEvents();
                      return PopularEventsCarousel(events: carouselEvents);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Filter Chips (Tarih ve Kategori Filtreleri)
                RepaintBoundary(
                  child: SizedBox(
                    height: 60,
                    child: Consumer<MockEventService>(
                      builder: (context, eventService, child) {
                        final filterItems = [
                          'Tümü',
                          'Bugün',
                          'Bu Hafta',
                          'Bu Ay',
                          'Konser',
                          'Tiyatro',
                          'Stand-up',
                          'Festival',
                        ];

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          cacheExtent: 250,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filterItems.length,
                          itemBuilder: (context, index) {
                            final item = filterItems[index];

                            bool isSelected = false;
                            if (item == 'Tümü') {
                              isSelected = eventService.selectedDateFilter == 'Tümü' &&
                                  eventService.selectedCategory == 'Tümü';
                            } else if (item == 'Bugün' || item == 'Bu Hafta' || item == 'Bu Ay') {
                              isSelected = eventService.selectedDateFilter == item;
                            } else {
                              isSelected = eventService.selectedCategory == item;
                            }

                            Widget? avatarWidget;
                            if (item == 'Tümü') {
                              avatarWidget = const Icon(Icons.explore_rounded, size: 15, color: Colors.white);
                            } else if (item == 'Bugün') {
                              avatarWidget = const Icon(Icons.local_fire_department_rounded, size: 15, color: Colors.orangeAccent);
                            } else if (item == 'Bu Hafta') {
                              avatarWidget = const Icon(Icons.flash_on_rounded, size: 15, color: Colors.amberAccent);
                            } else if (item == 'Bu Ay') {
                              avatarWidget = const Icon(Icons.calendar_month_rounded, size: 15, color: Colors.cyanAccent);
                            } else if (item == 'Konser') {
                              avatarWidget = const Icon(Icons.music_note_rounded, size: 15, color: Colors.white);
                            } else if (item == 'Tiyatro') {
                              avatarWidget = const Icon(Icons.theater_comedy_rounded, size: 15, color: Colors.white);
                            } else if (item == 'Stand-up') {
                              avatarWidget = const Icon(Icons.sentiment_very_satisfied_rounded, size: 15, color: Colors.white);
                            } else if (item == 'Festival') {
                              avatarWidget = const Icon(Icons.festival_rounded, size: 15, color: Colors.white);
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: avatarWidget,
                                label: Text(item),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    HapticFeedback.selectionClick();
                                    if (item == 'Tümü') {
                                      eventService.setDateFilter('Tümü');
                                      eventService.setCategory('Tümü');
                                    } else if (item == 'Bugün' || item == 'Bu Hafta' || item == 'Bu Ay') {
                                      eventService.setDateFilter(item);
                                    } else {
                                      eventService.setCategory(item);
                                    }
                                  }
                                },
                                selectedColor: AppColors.primary.withValues(alpha: 0.25),
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
                // Aktif Filtre Çipleri Göstergesi
                Consumer<MockEventService>(
                  builder: (context, eventService, child) {
                    final bool hasCityFilter = eventService.selectedCity != 'Tüm Şehirler' && eventService.selectedCity != 'Tümü';
                    final bool hasCategoryFilter = eventService.selectedCategory != 'Tümü';
                    final bool hasDateFilter = eventService.selectedDateFilter != 'Tümü';
                    final bool hasAnyFilter = hasCityFilter || hasCategoryFilter || hasDateFilter;

                    if (!hasAnyFilter) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'Aktif:',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (hasCityFilter)
                              _buildActiveFilterTag(
                                label: '📍 ${eventService.selectedCity}',
                                onClear: () {
                                  HapticFeedback.lightImpact();
                                  eventService.setCity('Tüm Şehirler');
                                },
                              ),
                            if (hasCategoryFilter)
                              _buildActiveFilterTag(
                                label: '🏷️ ${eventService.selectedCategory}',
                                onClear: () {
                                  HapticFeedback.lightImpact();
                                  eventService.setCategory('Tümü');
                                },
                              ),
                            if (hasDateFilter)
                              _buildActiveFilterTag(
                                label: '📅 ${eventService.selectedDateFilter}',
                                onClear: () {
                                  HapticFeedback.lightImpact();
                                  eventService.setDateFilter('Tümü');
                                },
                              ),
                            TextButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                eventService.resetFilters();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Temizle',
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                Consumer<MockEventService>(
                  builder: (context, eventService, child) {
                    final count = eventService.filteredEvents.length;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.manage_search_rounded, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '"${_searchController.text.trim()}" için $count Etkinlik Bulundu',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _searchController.clear();
                                eventService.setSearchQuery('');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  'Temizle',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        // Liste Başlığı ve Etkinlik Sayacı
        SliverToBoxAdapter(
          child: Consumer<MockEventService>(
            builder: (context, eventService, child) {
              final events = eventService.filteredEvents;
              if (events.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Arama Sonuçları'
                          : (eventService.selectedCategory != 'Tümü'
                              ? '${eventService.selectedCategory} Etkinlikleri'
                              : 'Yaklaşan Etkinlikler'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        '${events.length} Etkinlik',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Lazy-loaded Event List (Zero-lag rendering with RepaintBoundary & automatic keep-alives)
        Consumer<MockEventService>(
          builder: (context, eventService, child) {
            final events = eventService.filteredEvents;

            if (events.isEmpty) {
              final bool isSearching = _searchController.text.trim().isNotEmpty;
              final bool hasFilter = (eventService.selectedCity != 'Tüm Şehirler' && eventService.selectedCity != 'Tümü') ||
                  eventService.selectedCategory != 'Tümü' ||
                  eventService.selectedDateFilter != 'Tümü';

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Icon(
                            isSearching ? Icons.search_off_rounded : Icons.event_busy_rounded,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isSearching
                              ? '"${_searchController.text.trim()}" ile eşleşen etkinlik bulunamadı'
                              : (hasFilter
                                  ? 'Seçili filtrelerle eşleşen etkinlik bulunamadı'
                                  : 'Şu anda gösterilecek etkinlik bulunmuyor'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isSearching
                              ? 'Farklı bir arama terimi deneyebilir veya filtreleri sıfırlayabilirsiniz.'
                              : 'Farklı bir şehir veya kategori seçerek diğer etkinlikleri keşfedin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                        if (isSearching || hasFilter) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _searchController.clear();
                              eventService.resetFilters();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Filtreleri Sıfırla & Tümünü Gör', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ],
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
                          HapticFeedback.lightImpact();
                          eventService.resetFilters();
                          setModalState(() {});
                        },
                        child: Text('Sıfırla', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                            HapticFeedback.selectionClick();
                            eventService.setCity(selected ? city : 'Tüm Şehirler');
                            setModalState(() {});
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
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Tarih Filtresi',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: eventService.dateFilters.map((df) {
                      final isSelected = eventService.selectedDateFilter == df;
                      return ChoiceChip(
                        label: Text(df),
                        selected: isSelected,
                        onSelected: (selected) {
                          HapticFeedback.selectionClick();
                          eventService.setDateFilter(selected ? df : 'Tümü');
                          setModalState(() {});
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.category_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Kategoriler',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
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
                          HapticFeedback.selectionClick();
                          eventService.setCategory(selected ? cat : 'Tümü');
                          setModalState(() {});
                        },
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
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
