import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/models/event_model.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/widgets/popular_events_carousel.dart';

class CarouselManagerScreen extends StatefulWidget {
  const CarouselManagerScreen({super.key});

  @override
  State<CarouselManagerScreen> createState() => _CarouselManagerScreenState();
}

class _CarouselManagerScreenState extends State<CarouselManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  bool _showLivePreview = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Kayan Ekran Vitrin Yönetimi',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showLivePreview ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: AppColors.primary,
            ),
            tooltip: _showLivePreview ? 'Önizlemeyi Gizle' : 'Önizlemeyi Göster',
            onPressed: () {
              setState(() {
                _showLivePreview = !_showLivePreview;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.view_carousel_rounded, size: 20), text: 'Vitrindekiler (Sıralama)'),
            Tab(icon: Icon(Icons.add_to_photos_rounded, size: 20), text: 'Tüm Etkinliklerden Seç'),
          ],
        ),
      ),
      body: Consumer<MockEventService>(
        builder: (context, eventService, child) {
          final allEvents = eventService.getAdminEvents();
          final carouselEvents = eventService.getCarouselEvents();
          final selectedIds = eventService.featuredCarouselEventIds;

          return Column(
            children: [
              // Canlı Vitrin Önizlemesi (Live Preview)
              if (_showLivePreview) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Canlı Vitrin Önizlemesi (${carouselEvents.length} Etkinlik)',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (selectedIds.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                eventService.saveCarouselSettings([]);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vitrin otomatik popüler sıralamasına sıfırlandı.')),
                                );
                              },
                              icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Colors.orangeAccent),
                              label: const Text(
                                'Otomatik Popülere Dön',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: PopularEventsCarousel(
                          events: carouselEvents,
                          height: 190,
                          showIndicators: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // TabBar İçeriği
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Seçili Vitrin Etkinlikleri ve Sıralama
                    _buildFeaturedListTab(context, eventService, carouselEvents, selectedIds),

                    // TAB 2: Tüm Etkinlikler Listesi & Arama & Seçim
                    _buildAllEventsSelectorTab(context, eventService, allEvents, selectedIds),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturedListTab(
    BuildContext context,
    MockEventService eventService,
    List<EventModel> carouselEvents,
    List<String> selectedIds,
  ) {
    if (carouselEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_carousel_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Vitrinde gösterilecek etkinlik bulunamadı.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vitrinde Gösterilenler (${carouselEvents.length})',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              Text(
                selectedIds.isEmpty ? '(Otomatik Popüler)' : '(Özel Seçim)',
                style: TextStyle(
                  color: selectedIds.isEmpty ? Colors.cyanAccent : AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: carouselEvents.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final currentList = List<String>.from(
                selectedIds.isNotEmpty ? selectedIds : carouselEvents.map((e) => e.id),
              );
              final item = currentList.removeAt(oldIndex);
              currentList.insert(newIndex, item);
              eventService.saveCarouselSettings(currentList);
            },
            itemBuilder: (context, index) {
              final event = carouselEvents[index];
              return Container(
                key: ValueKey(event.id),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: event.imageUrl.startsWith('http')
                            ? Image.network(
                                event.imageUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.black26,
                                  child: Icon(Icons.event, color: AppColors.primary, size: 20),
                                ),
                              )
                            : Image.asset(
                                event.imageUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.black26,
                                  child: Icon(Icons.event, color: AppColors.primary, size: 20),
                                ),
                              ),
                      ),
                    ],
                  ),
                  title: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${event.category} • ${event.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Vitrinden Kaldır',
                        onPressed: () {
                          final currentList = List<String>.from(
                            selectedIds.isNotEmpty ? selectedIds : carouselEvents.map((e) => e.id),
                          );
                          currentList.remove(event.id);
                          eventService.saveCarouselSettings(currentList);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${event.title}" vitrinden kaldırıldı.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const Icon(Icons.drag_handle_rounded, color: Colors.white38),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllEventsSelectorTab(
    BuildContext context,
    MockEventService eventService,
    List<EventModel> allEvents,
    List<String> selectedIds,
  ) {
    final filtered = allEvents.where((e) {
      if (_searchFilter.trim().isEmpty) return true;
      final query = _searchFilter.toLowerCase();
      return e.title.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.location.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        // Arama Kutusu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchFilter = val;
              });
            },
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Etkinlik, sanatçı veya şehir ara...',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              suffixIcon: _searchFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchFilter = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Aramanızla eşleşen etkinlik bulunamadı.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final event = filtered[index];
                    final isFeatured = selectedIds.contains(event.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isFeatured ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFeatured ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
                          width: isFeatured ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: event.imageUrl.startsWith('http')
                              ? Image.network(
                                  event.imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.black26,
                                    child: Icon(Icons.event, color: AppColors.primary, size: 20),
                                  ),
                                )
                              : Image.asset(
                                  event.imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.black26,
                                    child: Icon(Icons.event, color: AppColors.primary, size: 20),
                                  ),
                                ),
                        ),
                        title: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${event.category} • ${event.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        trailing: InkWell(
                          onTap: () {
                            eventService.toggleCarouselFeatured(event.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  !isFeatured
                                      ? '🌟 "${event.title}" kayan vitrine eklendi!'
                                      : '❌ "${event.title}" vitrinden çıkarıldı.',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: isFeatured ? AppColors.primaryGradient : null,
                              color: isFeatured ? null : Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isFeatured ? Colors.transparent : Colors.white24,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 16,
                                  color: isFeatured ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFeatured ? 'Vitrinde' : 'Vitrini Ekle',
                                  style: TextStyle(
                                    color: isFeatured ? Colors.white : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
