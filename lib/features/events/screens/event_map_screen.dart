import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_launcher_helper.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../../../core/widgets/location_permission_dialog.dart';
import '../services/mock_event_service.dart';
import '../services/location_radar_service.dart';
import '../services/mock_match_service.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../widgets/match_dialog.dart';
import 'event_detail_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../messages/screens/chat_detail_screen.dart';
import '../../messages/services/mock_message_service.dart';
import '../../../services/notification_service.dart';

enum MapMode {
  events,
  matchMap,
}

class EventMapScreen extends StatefulWidget {
  const EventMapScreen({super.key});

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  late final MapController _mapController;
  Position? _currentPosition;
  EventModel? _selectedEvent;
  UserModel? _selectedUser;
  MapMode _currentMapMode = MapMode.events;
  String? _selectedCategoryFilter;
  String? _selectedDateFilter;
  String _selectedMapStyle = 'google'; // 'google', 'satellite', 'dark', 'osm'
  bool _hasAutoFittedBounds = false;

  // Eşleşme isteği için mesaj kontrolcüsü
  final TextEditingController _matchNoteController = TextEditingController();
  bool _isWritingMatchMessage = false;

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

  @override
  void dispose() {
    _matchNoteController.dispose();
    super.dispose();
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
    } else if (lower.contains('festival')) {
      return const Color(0xFF8B5CF6); // Mor
    }
    return const Color(0xFFEF4444); // Kırmızı
  }

  bool _matchesCategory(EventModel event, String filter) {
    if (filter == 'Tümü') return true;
    final cat = event.category.toLowerCase();
    final title = event.title.toLowerCase();
    final desc = event.description.toLowerCase();
    final f = filter.toLowerCase();

    if (f == 'konser') {
      return cat.contains('konser') || cat.contains('müzik') || cat.contains('music') || title.contains('konser');
    } else if (f == 'tiyatro') {
      return cat.contains('tiyatro') || cat.contains('arts') || cat.contains('theatre') || cat.contains('sahne') || title.contains('tiyatro');
    } else if (f == 'stand-up') {
      return cat.contains('stand-up') || cat.contains('stand up') || cat.contains('stand') || cat.contains('comedy') || cat.contains('komedi') ||
             title.contains('stand-up') || title.contains('stand up') || title.contains('stand') || title.contains('komedi') || title.contains('özdemir') || title.contains('demirkol') || title.contains('gösteri') || desc.contains('stand-up');
    } else if (f == 'festival') {
      return cat.contains('festival') || cat.contains('fest') || cat.contains('parti') ||
             title.contains('festival') || title.contains('fest') || desc.contains('festival');
    }
    return cat.contains(f) || title.contains(f);
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

  // YALNIZCA GERÇEK KULLANICILAR: Radarını açan ve konum paylaşımına izin veren kullanıcılar
  List<UserModel> _getActiveMatchUsers(LocationRadarService radarService, UserModel currentUser) {
    final Map<String, UserModel> usersMap = {};
    final myId = currentUser.id.toLowerCase().trim();
    final myName = currentUser.name.toLowerCase().trim();

    for (var u in radarService.nearbyUsers) {
      final uId = u.id.toLowerCase().trim();
      final uName = u.name.toLowerCase().trim();
      if (uId.isNotEmpty &&
          uId != myId &&
          uName != myName &&
          u.enableLocationSharing &&
          u.latitude != null &&
          u.longitude != null) {
        usersMap[uId] = u;
      }
    }

    return usersMap.values.toList();
  }

  String _getDistanceString(double targetLat, double targetLng) {
    if (_currentPosition == null) return 'İstanbul';
    final distanceMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLng,
    );
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m uzakta';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km uzakta';
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

  Future<void> _sendMatchRequestFromMap(UserModel targetUser) async {
    final matchService = context.read<MockMatchService>();
    final msgService = context.read<MockMessageService>();
    final note = _matchNoteController.text.trim();
    final initialMessage = note.isNotEmpty ? note : null;

    setState(() {
      _isWritingMatchMessage = false;
    });
    _matchNoteController.clear();

    final isMutualMatch = await matchService.swipeRight(targetUser, initialMessage: initialMessage);

    if (mounted) {
      if (isMutualMatch) {
        final chat = msgService.createOrGetChatForUser(targetUser, initialMessage: initialMessage);
        await msgService.reloadChats();
        if (!mounted) return;

        MatchDialog.show(
          context,
          matchedUser: targetUser,
          onSendMessage: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(chat: chat),
              ),
            );
          },
        );
      } else {
        if (initialMessage != null && initialMessage.isNotEmpty) {
          msgService.createOrGetChatForUser(targetUser, initialMessage: initialMessage);
        }

        final myName = context.read<MockEventService>().currentUser.name;
        final myId = context.read<MockEventService>().currentUser.id;

        NotificationService().sendMatchRequestPushNotification(
          receiverId: targetUser.id,
          senderName: myName.isNotEmpty ? myName : 'Biri',
          source: 'map',
        );

        if (initialMessage != null && initialMessage.isNotEmpty) {
          NotificationService().sendRemotePushNotification(
            receiverId: targetUser.id,
            senderName: myName.isNotEmpty ? myName : 'Biri',
            content: initialMessage,
            senderId: myId,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${targetUser.name} kişisine eşleşme isteğiniz iletildi. Kabul ettiğinde sohbet başlayacak.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final radarService = context.watch<LocationRadarService>();
    final matchService = context.watch<MockMatchService>();
    final msgService = context.watch<MockMessageService>();
    final currentUser = eventService.currentUser;
    final allEvents = eventService.allEvents;
    final now = DateTime.now();

    final activeMatchUsers = _getActiveMatchUsers(radarService, currentUser);

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

    // Tarih & Canlı Konum Filtreleme (Seçim yoksa varsayılan tüm tarihler gösterilir)
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

    // Akıllı Kategori Filtreleme (Seçim yoksa veya 'Tümü' ise tüm kategoriler gösterilir)
    if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'Tümü') {
      mapEvents = mapEvents.where((e) => _matchesCategory(e, _selectedCategoryFilter!)).toList();
    }

    // İlk açılışta etkinliklerin tamamını kapsayacak şekilde kadrajla
    if (!_hasAutoFittedBounds && mapEvents.isNotEmpty && _currentPosition == null) {
      _hasAutoFittedBounds = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBoundsToEvents(mapEvents);
      });
    }

    // Varsayılan Merkez: Kullanıcı Konumu veya İstanbul (41.0082, 28.9784)
    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (mapEvents.isNotEmpty
            ? LatLng(mapEvents.first.latitude!, mapEvents.first.longitude!)
            : const LatLng(41.0082, 28.9784));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Üst Segmented Kontrolcü: Etkinlikler vs Match Haritası
        title: Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Etkinlikler Modu
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentMapMode = MapMode.events;
                    _selectedUser = null;
                    _isWritingMatchMessage = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: _currentMapMode == MapMode.events ? AppColors.primaryGradient : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_rounded,
                        size: 15,
                        color: _currentMapMode == MapMode.events ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Etkinlikler',
                        style: TextStyle(
                          color: _currentMapMode == MapMode.events ? Colors.white : AppColors.textSecondary,
                          fontWeight: _currentMapMode == MapMode.events ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 2. Match Haritası Modu (Gerçek Kullanıcı PP'leri & Canlı Konum)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentMapMode = MapMode.matchMap;
                    _selectedEvent = null;
                    _isWritingMatchMessage = false;
                  });
                  try {
                    context.read<LocationRadarService>().toggleRadar(true);
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: _currentMapMode == MapMode.matchMap
                        ? const LinearGradient(colors: [Color(0xFFFFB703), Color(0xFFFF0055)])
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 15,
                        color: _currentMapMode == MapMode.matchMap ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Match Haritası',
                        style: TextStyle(
                          color: _currentMapMode == MapMode.matchMap ? Colors.white : AppColors.textSecondary,
                          fontWeight: _currentMapMode == MapMode.matchMap ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        ],
      ),
      body: Stack(
        children: [
          // 1. Harita Katmanı & Pinler
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
                  _selectedUser = null;
                  _isWritingMatchMessage = false;
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

              // =================== ETKİNLİKLER MODU PINLERI ===================
              if (_currentMapMode == MapMode.events) ...[
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
                            _selectedUser = null;
                            _isWritingMatchMessage = false;
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
              ] else ...[
                // =================== MATCH HARİTASI MODU (GERÇEK KULLANICI PP PINLERI) ===================
                MarkerLayer(
                  markers: [
                    // Kendi Canlı Konumun (Konum Paylaşımı Açık ise)
                    if (currentUser.enableLocationSharing)
                      Marker(
                        point: LatLng(
                          _currentPosition?.latitude ?? currentUser.latitude ?? 41.0082,
                          _currentPosition?.longitude ?? currentUser.longitude ?? 28.9784,
                        ),
                        width: 56,
                        height: 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)]),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00F2FE).withOpacity(0.6),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: currentUser.avatarUrl.isNotEmpty
                                        ? AppImageWidget(imageUrl: currentUser.avatarUrl, fit: BoxFit.cover)
                                        : const Icon(Icons.person, color: Colors.white),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Sen 📍',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Canlı Radardaki Gerçek Kullanıcıların Profil Fotoğraflı (PP) Pinleri
                    ...activeMatchUsers.map((user) {
                      final isSelected = _selectedUser?.id == user.id;
                      return Marker(
                        point: LatLng(user.latitude!, user.longitude!),
                        width: isSelected ? 56 : 48,
                        height: isSelected ? 72 : 64,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedUser = user;
                              _selectedEvent = null;
                              _isWritingMatchMessage = false;
                            });
                            _mapController.move(
                              LatLng(user.latitude!, user.longitude!),
                              14.5,
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: isSelected ? 46 : 40,
                                    height: isSelected ? 46 : 40,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isSelected
                                          ? const LinearGradient(colors: [Color(0xFFFFB703), Color(0xFFFF0055)])
                                          : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isSelected ? const Color(0xFFFF0055) : const Color(0xFF8B5CF6)).withOpacity(0.55),
                                          blurRadius: isSelected ? 12 : 6,
                                          spreadRadius: isSelected ? 2 : 0,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: AppImageWidget(
                                        imageUrl: user.avatarUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFFFB703) : Colors.white24,
                                    width: isSelected ? 1 : 0.5,
                                  ),
                                ),
                                child: Text(
                                  user.name.split(' ').first,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),

          // 2. Üst Kontrol Paneli (Etkinlik Filtresi veya Match Haritası Durum Barı)
          if (_currentMapMode == MapMode.events)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: ['🔥 Bugün', '📍 En Yakın (< 10 km)', '⚡ Bu Hafta'].map((dateFilter) {
                        final isSelected = _selectedDateFilter == dateFilter;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedDateFilter == dateFilter) {
                                _selectedDateFilter = null;
                              } else {
                                _selectedDateFilter = dateFilter;
                              }
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: eventService.categories.where((c) => c != 'Tümü').map((category) {
                        final isSelected = _selectedCategoryFilter == category;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedCategoryFilter == category) {
                                _selectedCategoryFilter = null;
                              } else {
                                _selectedCategoryFilter = category;
                              }
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
            )
          else
            // Match Haritası Üst Durum & Gizlilik Barı (Tamamen Sessiz Geçiş, Altta SnackBar Açılmaz!)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: activeMatchUsers.isNotEmpty ? const Color(0xFF10B981) : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activeMatchUsers.isNotEmpty
                          ? '${activeMatchUsers.length} Kullanıcı Match Haritasında Canlı'
                          : 'Radarın Açık (Kullanıcı Aranıyor)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Hayalet Modu & Görünürlük Butonu (SnackBar gösterimi tamamen kaldırıldı)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          currentUser.enableLocationSharing = !currentUser.enableLocationSharing;
                        });
                        eventService.notifyListeners();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: currentUser.enableLocationSharing
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: currentUser.enableLocationSharing
                                ? const Color(0xFF10B981)
                                : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentUser.enableLocationSharing
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 13,
                              color: currentUser.enableLocationSharing
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentUser.enableLocationSharing ? 'Görünürsün' : 'Hayalet Modu',
                              style: TextStyle(
                                color: currentUser.enableLocationSharing
                                    ? const Color(0xFF10B981)
                                    : Colors.grey[300],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Sağ Alt Butonlar (Zoom ve Konumuma Git)
          Positioned(
            right: 16,
            bottom: (_selectedEvent != null || _selectedUser != null) ? 240 : 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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

          // 3. ETKİNLİK DETAY PANELİ
          if (_selectedEvent != null && _currentMapMode == MapMode.events)
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
                              children: [
                                Text(
                                  '${_selectedEvent!.dateTime.day.toString().padLeft(2, '0')}.${_selectedEvent!.dateTime.month.toString().padLeft(2, '0')}.${_selectedEvent!.dateTime.year}',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () async {
                                    final dest = (_selectedEvent!.latitude != null && _selectedEvent!.longitude != null)
                                        ? '${_selectedEvent!.latitude},${_selectedEvent!.longitude}'
                                        : Uri.encodeComponent(_selectedEvent!.location);
                                    final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$dest';
                                    await UrlLauncherHelper.launchURL(mapsUrl);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.near_me_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 3),
                                        Text(
                                          'Yol Tarifi Al',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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

          // 4. MATCH HARİTASI KULLANICI PROFİL KARTI
          if (_selectedUser != null && _currentMapMode == MapMode.matchMap)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kullanıcı Başlık Bilgisi
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                              ),
                              child: ClipOval(
                                child: AppImageWidget(
                                  imageUrl: _selectedUser!.avatarUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.surface, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // İsim, Doğrulama Rozeti ve Mesafe
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _selectedUser!.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Doğrulanmış Profil Rozeti: SADECE mail doğrulaması olanlarda gözükür!
                                  if (_selectedUser!.isVerified) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF38BDF8)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${_selectedUser!.username ?? _selectedUser!.name.toLowerCase().replaceAll(' ', '')}',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFEC4899)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      '${_selectedUser!.city ?? "İstanbul"} • ${_getDistanceString(_selectedUser!.latitude!, _selectedUser!.longitude!)}',
                                      style: const TextStyle(color: Color(0xFFEC4899), fontSize: 11.5, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Kapat Butonu
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedUser = null;
                              _isWritingMatchMessage = false;
                            });
                          },
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    // Biyografi (Varsa)
                    if (_selectedUser!.aboutMe != null && _selectedUser!.aboutMe!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedUser!.aboutMe!,
                                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Eşleşme Mesaj Yazma Alanı (İsteğe bağlı not ekleme)
                    if (_isWritingMatchMessage) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                        ),
                        child: TextField(
                          controller: _matchNoteController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: '${_selectedUser!.name} kişisine bir tanışma mesajı yaz...',
                            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Aksiyon Butonları
                    Builder(
                      builder: (context) {
                        final isAlreadyMatched = msgService.individualChats.any(
                          (c) => c.participant.id.toLowerCase() == _selectedUser!.id.toLowerCase(),
                        );
                        final hasSentReq = matchService.hasSentRequest('map', _selectedUser!.id);

                        return Row(
                          children: [
                            // 1. Eşleşme İsteği / Sohbet Butonu
                            Expanded(
                              flex: 3,
                              child: isAlreadyMatched
                                  ? ElevatedButton.icon(
                                      onPressed: () {
                                        final chat = msgService.createOrGetChatForUser(_selectedUser!);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                      ),
                                      icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                                      label: const Text(
                                        'Sohbete Git',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  : hasSentReq
                                      ? Container(
                                          height: 42,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.white24),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF38BDF8)),
                                              SizedBox(width: 6),
                                              Text(
                                                'İstek Gönderildi',
                                                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        )
                                      : _isWritingMatchMessage
                                          ? Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => _sendMatchRequestFromMap(_selectedUser!),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primary,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                    ),
                                                    icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                                                    label: const Text(
                                                      'İsteği Gönder',
                                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _isWritingMatchMessage = false;
                                                    });
                                                  },
                                                  icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                                                ),
                                              ],
                                            )
                                          : Container(
                                              height: 42,
                                              decoration: BoxDecoration(
                                                gradient: AppColors.primaryGradient,
                                                borderRadius: BorderRadius.circular(14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary.withOpacity(0.35),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _isWritingMatchMessage = true;
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.transparent,
                                                  shadowColor: Colors.transparent,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                ),
                                                icon: const Icon(Icons.favorite_rounded, size: 16, color: Colors.white),
                                                label: const Text(
                                                  'Eşleşme İsteği Gönder',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                            ),
                            const SizedBox(width: 10),
                            // 2. Profili Gör Butonu
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 42,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserProfileScreen(user: _selectedUser!),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  icon: const Icon(Icons.person_outline_rounded, size: 16, color: Colors.white70),
                                  label: const Text(
                                    'Profili Gör',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
