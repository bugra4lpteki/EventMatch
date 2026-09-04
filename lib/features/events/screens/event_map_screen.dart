import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/location_permission_dialog.dart';
import '../services/mock_event_service.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';

class EventMapScreen extends StatefulWidget {
  const EventMapScreen({super.key});

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  late final MapController _mapController;
  Position? _currentPosition;
  EventModel? _selectedEvent;
  String _selectedCategoryFilter = 'Tümü';
  String _selectedDateFilter = '🌐 Tüm Tarihler';
  String _selectedMapStyle = 'google'; // 'google', 'dark', 'light', 'osm'
  bool _hasAutoFittedBounds = false;

  bool _isSameDay(DateTime dt1, DateTime dt2) {
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  bool _isWithinDays(DateTime dt, int days) {
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    return dt.isAfter(now.subtract(const Duration(hours: 6))) && dt.isBefore(limit);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _checkPermissionAndGetLocation();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final granted = await LocationPermissionDialog.requestLocationWithPreDialog(context);
          if (!granted) return;
        }
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      if (_currentPosition != null) {
        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          12.5,
        );
      }
    } catch (_) {}
  }

  void _fitBoundsToEvents(List<EventModel> events) {
    if (events.isEmpty) return;
    try {
      if (events.length == 1) {
        final e = events.first;
        _mapController.move(LatLng(e.latitude!, e.longitude!), 13.5);
        return;
      }
      double minLat = events.first.latitude!;
      double maxLat = events.first.latitude!;
      double minLng = events.first.longitude!;
      double maxLng = events.first.longitude!;

      for (var e in events) {
        if (e.latitude! < minLat) minLat = e.latitude!;
        if (e.latitude! > maxLat) maxLat = e.latitude!;
        if (e.longitude! < minLng) minLng = e.longitude!;
        if (e.longitude! > maxLng) maxLng = e.longitude!;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 11.5);
    } catch (_) {}
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('konser') || lower.contains('müzik') || lower.contains('music')) {
      return Icons.music_note_rounded;
    } else if (lower.contains('tiyatro') || lower.contains('sahne') || lower.contains('theatre') || lower.contains('arts')) {
      return Icons.theater_comedy_rounded;
    } else if (lower.contains('stand-up') || lower.contains('komedi') || lower.contains('comedy')) {
      return Icons.emoji_emotions_rounded;
    } else if (lower.contains('spor') || lower.contains('sport') || lower.contains('maç') || lower.contains('futbol')) {
      return Icons.sports_soccer_rounded;
    } else if (lower.contains('festival') || lower.contains('parti')) {
      return Icons.celebration_rounded;
    } else if (lower.contains('sergi') || lower.contains('sanat') || lower.contains('müze')) {
      return Icons.palette_rounded;
    } else if (lower.contains('atölye') || lower.contains('workshop') || lower.contains('eğitim')) {
      return Icons.handyman_rounded;
    }
    return Icons.event_rounded;
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('konser') || lower.contains('müzik')) {
      return const Color(0xFF6366F1); // Indigo / Mor
    } else if (lower.contains('tiyatro') || lower.contains('sahne')) {
      return const Color(0xFFEC4899); // Pembe
    } else if (lower.contains('stand-up') || lower.contains('komedi')) {
      return const Color(0xFFF59E0B); // Kehribar
    } else if (lower.contains('spor')) {
      return const Color(0xFF10B981); // Yeşil
    } else if (lower.contains('festival')) {
      return const Color(0xFF8B5CF6); // Mor
    }
    return const Color(0xFFEF4444); // Kırmızı
  }

  bool _matchesCategory(String eventCategory, String filter) {
    if (filter == 'Tümü') return true;
    final cat = eventCategory.toLowerCase();
    final f = filter.toLowerCase();

    if (f == 'konser') {
      return cat.contains('konser') || cat.contains('müzik') || cat.contains('music');
    } else if (f == 'tiyatro') {
      return cat.contains('tiyatro') || cat.contains('arts') || cat.contains('theatre') || cat.contains('sahne');
    } else if (f == 'stand-up') {
      return cat.contains('stand-up') || cat.contains('comedy') || cat.contains('komedi');
    } else if (f == 'spor') {
      return cat.contains('spor') || cat.contains('sports');
    } else if (f == 'festival') {
      return cat.contains('festival') || cat.contains('parti');
    }
    return cat.contains(f);
  }

  String _getMapTileUrl(String style) {
    switch (style) {
      case 'dark':
        // ESRI Dark Gray: %100 Temiz, filigransız, API key istemeyen karanlık mod
        return 'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
      case 'satellite':
        // GTA / Uydu Hibrit Görünümü: Gerçekçi arazi, yollar ve şehir dokusu
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'osm':
        // Klasik OpenStreetMap
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 'google':
      default:
        // Sade, temiz Google Harita Yol Katmanı
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  PopupMenuItem<String> _buildStyleMenuItem(String value, String label, IconData icon) {
    final isSelected = _selectedMapStyle == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final allEvents = eventService.allEvents;
    final now = DateTime.now();

    // Koordinatları olan tüm etkinlikler
    List<EventModel> mapEvents = allEvents.where((e) => e.latitude != null && e.longitude != null).toList();

    // Canlı GPS Mesafesine Göre Sıralama
    if (_currentPosition != null) {
      mapEvents.sort((a, b) {
        final dA = a.getDistanceInKm(_currentPosition!.latitude, _currentPosition!.longitude) ?? 99999;
        final dB = b.getDistanceInKm(_currentPosition!.latitude, _currentPosition!.longitude) ?? 99999;
        return dA.compareTo(dB);
      });
    }

    // Tarih & Canlı Konum Filtreleme (Varsayılan: 🔥 Bugün)
    if (_selectedDateFilter == '🔥 Bugün') {
      final todayEvents = mapEvents.where((e) => _isSameDay(e.dateTime, now) || _isWithinDays(e.dateTime, 1)).toList();
      if (todayEvents.isNotEmpty) {
        mapEvents = todayEvents;
      }
    } else if (_selectedDateFilter == '📍 En Yakın (< 10 km)' && _currentPosition != null) {
      final nearby = mapEvents.where((e) {
        final dist = e.getDistanceInKm(_currentPosition!.latitude, _currentPosition!.longitude);
        return dist != null && dist <= 10.0;
      }).toList();
      if (nearby.isNotEmpty) {
        mapEvents = nearby;
      }
    } else if (_selectedDateFilter == '⚡ Bu Hafta') {
      mapEvents = mapEvents.where((e) => _isWithinDays(e.dateTime, 7)).toList();
    }

    // Akıllı Kategori Filtreleme
    if (_selectedCategoryFilter != 'Tümü') {
      mapEvents = mapEvents.where((e) => _matchesCategory(e.category, _selectedCategoryFilter)).toList();
    }

    // İlk açılışta etkinliklerin tamamını kapsayacak şekilde kadrajla
    if (!_hasAutoFittedBounds && mapEvents.isNotEmpty && _currentPosition == null) {
      _hasAutoFittedBounds = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBoundsToEvents(mapEvents);
      });
    }

    // Varsayılan Merkez: İstanbul (41.0082, 28.9784)
    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (mapEvents.isNotEmpty
            ? LatLng(mapEvents.first.latitude!, mapEvents.first.longitude!)
            : const LatLng(41.0082, 28.9784));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Etkinlik Haritası',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Harita Görünümü',
            icon: Icon(Icons.layers_rounded, color: AppColors.primary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (style) {
              setState(() {
                _selectedMapStyle = style;
              });
            },
            itemBuilder: (context) => [
              _buildStyleMenuItem('google', '🗺️ Google Harita (Temiz/Sade)', Icons.map_rounded),
              _buildStyleMenuItem('satellite', '🛰️ Uydu Hibrit (Canlı Arazi)', Icons.satellite_alt_rounded),
              _buildStyleMenuItem('dark', '🌙 Gece Modu (Karanlık/Modern)', Icons.dark_mode_rounded),
            ],
          ),
          IconButton(
            tooltip: 'Tüm Etkinliklere Odaklan',
            icon: Icon(Icons.fit_screen_rounded, color: AppColors.primary),
            onPressed: () {
              if (mapEvents.isNotEmpty) {
                _fitBoundsToEvents(mapEvents);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Seçilen Harita Katmanı
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 11.5,
              minZoom: 4,
              maxZoom: 19,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedEvent = null;
                });
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_selectedMapStyle),
                urlTemplate: _getMapTileUrl(_selectedMapStyle),
                userAgentPackageName: 'com.eventmatch.app',
                tileProvider: NetworkTileProvider(),
                panBuffer: 1,
                keepBuffer: 3,
                maxNativeZoom: 19,
              ),
              // Kullanıcı Konumu İkonu
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              // Kompakt Şık Etkinlik İkonları
              MarkerLayer(
                markers: mapEvents.map((event) {
                  final isSelected = _selectedEvent?.id == event.id;
                  final pinColor = _getCategoryColor(event.category);
                  return Marker(
                    point: LatLng(event.latitude!, event.longitude!),
                    width: isSelected ? 38 : 30,
                    height: isSelected ? 38 : 30,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEvent = event;
                        });
                        _mapController.move(
                          LatLng(event.latitude!, event.longitude!),
                          14,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : pinColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: (isSelected ? AppColors.primary : pinColor).withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(event.category),
                          color: Colors.white,
                          size: isSelected ? 19 : 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Üst Tarih & Kategori Filtreleme Barı
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tarih Filtresi
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['🔥 Bugün', '📍 En Yakın (< 10 km)', '⚡ Bu Hafta', '🌐 Tüm Tarihler'].map((dateFilter) {
                      final isSelected = _selectedDateFilter == dateFilter;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDateFilter = dateFilter;
                            _selectedEvent = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.primaryGradient : null,
                            color: isSelected ? null : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.white12,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            dateFilter,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Kategori Filtresi
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['Tümü', 'Konser', 'Tiyatro', 'Stand-up', 'Spor', 'Festival'].map((category) {
                      final isSelected = _selectedCategoryFilter == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryFilter = category;
                            _selectedEvent = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surface.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.white10,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? AppColors.primaryVariant : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 2.1 Sonuç Bulunamadı Bilgilendirme Rozeti
          if (mapEvents.isEmpty)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Seçili filtreye uygun etkinlik bulunamadı. Filtreyi sıfırlayabilirsiniz.',
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategoryFilter = 'Tümü';
                          _selectedDateFilter = '🌐 Tüm Tarihler';
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sıfırla', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Sağ Alt Butonlar (Zoom ve Konumuma Git)
          Positioned(
            right: 16,
            bottom: _selectedEvent != null ? 220 : 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In (+)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom + 1);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.add, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Zoom Out (-)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom - 1);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.remove, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Konumuma Git FAB
                FloatingActionButton.small(
                  heroTag: 'my_location_btn',
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.my_location, color: AppColors.primary),
                  onPressed: () {
                    if (_currentPosition != null) {
                      _mapController.move(
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        14,
                      );
                    } else {
                      _checkPermissionAndGetLocation();
                    }
                  },
                ),
              ],
            ),
          ),

          // 4. Seçili Etkinlik Detay Paneli (Bottom Sheet)
          if (_selectedEvent != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailScreen(event: _selectedEvent!),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: _selectedEvent!.imageUrl.startsWith('http')
                              ? Image.network(_selectedEvent!.imageUrl, fit: BoxFit.cover)
                              : Image.asset(_selectedEvent!.imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedEvent!.title,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 13),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _selectedEvent!.location,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_selectedEvent!.dateTime.day}.${_selectedEvent!.dateTime.month}.${_selectedEvent!.dateTime.year}',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                if (_selectedEvent!.effectiveTicketUrl.isNotEmpty)
                                  GestureDetector(
                                    onTap: () async {
                                      await UrlLauncherHelper.launchURL(_selectedEvent!.effectiveTicketUrl);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'BİLET AL',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
