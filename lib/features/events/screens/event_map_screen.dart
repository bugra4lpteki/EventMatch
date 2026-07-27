import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
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
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
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

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('konser') || lower.contains('müzik')) {
      return Icons.music_note_rounded;
    } else if (lower.contains('tiyatro') || lower.contains('sahne')) {
      return Icons.theater_comedy_rounded;
    } else if (lower.contains('stand-up') || lower.contains('komedi')) {
      return Icons.emoji_emotions_rounded;
    }
    return Icons.event_rounded;
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
    }
    return cat.contains(f);
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final allEvents = eventService.allEvents;

    // Koordinatları olan etkinlikler
    List<EventModel> mapEvents = allEvents.where((e) => e.latitude != null && e.longitude != null).toList();

    // Akıllı Kategori Filtreleme
    if (_selectedCategoryFilter != 'Tümü') {
      mapEvents = mapEvents.where((e) => _matchesCategory(e.category, _selectedCategoryFilter)).toList();
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
      ),
      body: Stack(
        children: [
          // 1. Kesintisiz 100% Ücretsiz Harita Katmanı (OpenStreetMap / Carto Voyager)
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
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.eventmatch.app',
                tileProvider: NetworkTileProvider(),
                panBuffer: 1,
                keepBuffer: 3,
                maxNativeZoom: 18,
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
              // Kompakt Şık Etkinlik İkonları (KÜÇÜLTÜLMÜŞ MİNİ MAVİ/KIRMIZI PINLER)
              MarkerLayer(
                markers: mapEvents.map((event) {
                  final isSelected = _selectedEvent?.id == event.id;
                  return Marker(
                    point: LatLng(event.latitude!, event.longitude!),
                    width: isSelected ? 36 : 28,
                    height: isSelected ? 36 : 28,
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
                          color: isSelected ? AppColors.primary : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(
                          _getCategoryIcon(event.category),
                          color: Colors.white,
                          size: isSelected ? 18 : 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Üst Kategori Filtreleme Barı
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['Tümü', 'Konser', 'Tiyatro', 'Stand-up'].map((category) {
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 3. Konumuma Git Butonu
          Positioned(
            right: 16,
            bottom: _selectedEvent != null ? 220 : 20,
            child: FloatingActionButton.small(
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
