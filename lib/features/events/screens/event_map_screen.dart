import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../models/map_poi_model.dart';
import '../services/map_poi_service.dart';
import '../widgets/match_dialog.dart';
import 'event_detail_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/widgets/vip_paywall_sheet.dart';
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
  MapPoiModel? _selectedPoi;
  bool _showParking = false;
  bool _showGasStations = false;
  MapMode _currentMapMode = MapMode.events;
  String? _selectedCategoryFilter;
  String? _selectedDateFilter;
  String _selectedMapStyle = 'google'; // 'google', 'satellite', 'dark', 'osm'
  bool _hasAutoFittedBounds = false;

  // Match Haritası Günlük Kota & Sayaç (Ücretsiz: 1 saat, VIP: Sınırsız)
  Timer? _matchMapQuotaTimer;
  int _matchMapRemainingSeconds = 3600;

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
    _loadMatchMapQuota();
  }

  Future<void> _loadMatchMapQuota() async {
    final eventService = context.read<MockEventService>();
    final rem = await eventService.getRemainingMatchMapSeconds();
    if (mounted) {
      setState(() => _matchMapRemainingSeconds = rem);
    }
  }

  void _startMatchMapTimer() {
    _matchMapQuotaTimer?.cancel();
    _matchMapQuotaTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _currentMapMode != MapMode.matchMap) return;
      final eventService = context.read<MockEventService>();
      if (eventService.currentUser.hasActiveVip) return;
      await eventService.recordMatchMapUsage(seconds: 5);
      final rem = await eventService.getRemainingMatchMapSeconds();
      if (mounted) {
        setState(() => _matchMapRemainingSeconds = rem);
      }
    });
  }

  @override
  void dispose() {
    _matchMapQuotaTimer?.cancel();
    _matchNoteController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndGetLocation({bool forceCenter = false}) async {
    try {
      // 1. Kullanıcı mock/profil konumunu anında hazırda tut (anında gösterim için)
      if (_currentPosition == null && mounted) {
        final currentUser = context.read<MockEventService>().currentUser;
        if (currentUser.latitude != null && currentUser.longitude != null) {
          if (forceCenter) {
            _mapController.move(LatLng(currentUser.latitude!, currentUser.longitude!), 13.5);
          }
        }
      }

      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true; // Web'de bazen UnsupportedError/istisna fırlatabilir
      }

      if (!serviceEnabled && !kIsWeb) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          final granted = await LocationPermissionDialog.requestLocationWithPreDialog(context);
          if (!granted) return;
        }
      }

      if (permission == LocationPermission.deniedForever) return;

      // 2. Mobil cihazlarda varsa son bilinen konumu anında al (Web'de patlamaması için kIsWeb kontrolü)
      if (!kIsWeb) {
        try {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null && mounted) {
            setState(() {
              _currentPosition = lastPos;
            });
            _mapController.move(
              LatLng(lastPos.latitude, lastPos.longitude),
              13.5,
            );
          }
        } catch (_) {}
      }

      // 3. Canlı konumu al
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: kIsWeb ? LocationAccuracy.high : LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          ),
        );
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            13.5,
          );
        }
      } catch (e) {
        debugPrint('[EventMapScreen] Canlı GPS alma hatası: $e');
      }
    } catch (e) {
      debugPrint('[EventMapScreen] Konum servisi genel hatası: $e');
    }
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

    final users = usersMap.values.toList();
    // ⚡ Boost'lanan profilleri harita ve radarda en öne sırala!
    users.sort((a, b) {
      if (a.isBoosted && !b.isBoosted) return -1;
      if (!a.isBoosted && b.isBoosted) return 1;
      return 0;
    });
    return users;
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

    final userLat = _currentPosition?.latitude ?? currentUser.latitude;
    final userLng = _currentPosition?.longitude ?? currentUser.longitude;

    // Sadece kullanıcının yakınındaki otoparkları göster (haritada aşırı kalabalık olmaması için)
    final nearbyParkingLots = _showParking
        ? MapPoiService().getNearbyParkingLots(
            lat: userLat,
            lng: userLng,
            maxKm: 6.0,
            limit: 25,
          )
        : <MapPoiModel>[];

    // Sadece kullanıcının yakınındaki benzinlikleri göster
    final nearbyGasStations = _showGasStations
        ? MapPoiService().getNearbyGasStations(
            lat: userLat,
            lng: userLng,
            maxKm: 8.0,
            limit: 15,
          )
        : <MapPoiModel>[];

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
              // 1. Etkinlikler Modu (Herkese tamamen ücretsiz ve açık)
              GestureDetector(
                onTap: () {
                  _matchMapQuotaTimer?.cancel();
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
              // 2. Match Haritası Modu (Ücretsiz: Günde 1 Saat, VIP: Sınırsız)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentMapMode = MapMode.matchMap;
                    _selectedEvent = null;
                    _isWritingMatchMessage = false;
                  });
                  _startMatchMapTimer();
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
                  _selectedPoi = null;
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
                panBuffer: 0,
                keepBuffer: 2,
                maxNativeZoom: 19,
              ),

              // =================== ETKİNLİKLER MODU PINLERI ===================
              if (_currentMapMode == MapMode.events) ...[
                // 📍 KULLANICININ CANLI KONUM PİNİ (ZARİF, PARLAK & TAŞMASIZ)
                if (userLat != null && userLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(userLat, userLng),
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00F2FE), Color(0xFF0284C7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.65),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.my_location_rounded, color: Colors.white, size: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                // 🎫 ETKİNLİK MARKERLARI (Otopark veya Benzinlik seçildiğinde harita karmaşasını önlemek için etkinlikler gizlenir)
                if (!_showParking && !_showGasStations)
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
                // 🅿️ OTOPARKLAR MARKER KATMANI (İBB İSPARK CANLI DOLULUK DESTEĞİ)
                if (_showParking)
                  MarkerLayer(
                    markers: nearbyParkingLots.map((poi) {
                      final isSelected = _selectedPoi?.id == poi.id;
                      final isFull = poi.isFull;
                      final primaryColor = isFull ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
                      final secondaryColor = isFull ? const Color(0xFF991B1B) : const Color(0xFF1D4ED8);
                      final highlightColor = isFull ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD);

                      return Marker(
                        point: LatLng(poi.latitude, poi.longitude),
                        width: isSelected ? 42 : 32,
                        height: isSelected ? 42 : 32,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPoi = poi;
                              _selectedEvent = null;
                              _selectedUser = null;
                              _isWritingMatchMessage = false;
                            });
                            _mapController.move(LatLng(poi.latitude, poi.longitude), 14.5);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? highlightColor : Colors.white,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.5),
                                  blurRadius: isSelected ? 10 : 5,
                                  spreadRadius: isSelected ? 2 : 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_parking_rounded,
                              color: Colors.white,
                              size: isSelected ? 22 : 16,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                // ⛽ BENZİNLİKLER MARKER KATMANI
                if (_showGasStations)
                  MarkerLayer(
                    markers: nearbyGasStations.map((poi) {
                      final isSelected = _selectedPoi?.id == poi.id;
                      return Marker(
                        point: LatLng(poi.latitude, poi.longitude),
                        width: isSelected ? 40 : 32,
                        height: isSelected ? 40 : 32,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPoi = poi;
                              _selectedEvent = null;
                              _selectedUser = null;
                              _isWritingMatchMessage = false;
                            });
                            _mapController.move(LatLng(poi.latitude, poi.longitude), 14.5);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF047857)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.5),
                                  blurRadius: isSelected ? 10 : 5,
                                  spreadRadius: isSelected ? 2 : 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_gas_station_rounded,
                              color: Colors.white,
                              size: isSelected ? 21 : 16,
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
                        width: currentUser.isBoosted ? 68 : 56,
                        height: currentUser.isBoosted ? 86 : 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                if (currentUser.isBoosted)
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withValues(alpha: 0.65),
                                          blurRadius: 18,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: currentUser.isBoosted
                                        ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)])
                                        : const LinearGradient(colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)]),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (currentUser.isBoosted ? Colors.amber : const Color(0xFF00F2FE)).withValues(alpha: 0.6),
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
                                      color: currentUser.isBoosted ? const Color(0xFFFFD700) : const Color(0xFF10B981),
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
                                gradient: currentUser.isBoosted
                                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)])
                                    : null,
                                color: currentUser.isBoosted ? null : const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                currentUser.isBoosted ? '⚡ SEN (BOOST)' : 'Sen 📍',
                                style: TextStyle(
                                  color: currentUser.isBoosted ? Colors.black : Colors.white,
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
                      final isUserBoosted = user.isBoosted;
                      return Marker(
                        point: LatLng(user.latitude!, user.longitude!),
                        width: isSelected ? 60 : 48,
                        height: isSelected ? 76 : 64,
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
                                alignment: Alignment.center,
                                children: [
                                  if (isUserBoosted)
                                    Container(
                                      width: isSelected ? 52 : 46,
                                      height: isSelected ? 52 : 46,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withValues(alpha: 0.6),
                                            blurRadius: 14,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    width: isSelected ? 46 : 40,
                                    height: isSelected ? 46 : 40,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isUserBoosted
                                          ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)])
                                          : (isSelected
                                              ? const LinearGradient(colors: [Color(0xFFFFB703), Color(0xFFFF0055)])
                                              : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)])),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isUserBoosted
                                              ? Colors.amber.withValues(alpha: 0.7)
                                              : (isSelected ? const Color(0xFFFF0055) : const Color(0xFF8B5CF6)).withOpacity(0.55),
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
                                        color: isUserBoosted ? const Color(0xFFFFD700) : const Color(0xFF10B981),
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
                                  color: isUserBoosted ? const Color(0xFFFFA000) : Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUserBoosted
                                        ? const Color(0xFFFFD700)
                                        : (isSelected ? const Color(0xFFFFB703) : Colors.white24),
                                    width: (isUserBoosted || isSelected) ? 1 : 0.5,
                                  ),
                                ),
                                child: Text(
                                  isUserBoosted ? '⚡ ${user.name.split(' ').first}' : user.name.split(' ').first,
                                  style: TextStyle(
                                    color: isUserBoosted ? Colors.black : Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: (isUserBoosted || isSelected) ? FontWeight.bold : FontWeight.w600,
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
          if (_currentMapMode == MapMode.matchMap)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (!currentUser.hasActiveVip) {
                      VipPaywallSheet.show(context, initialFeature: VipFeature.mapBoost);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151F).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: currentUser.hasActiveVip
                            ? const Color(0xFFF59E0B)
                            : Colors.white24,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          currentUser.hasActiveVip
                              ? Icons.workspace_premium_rounded
                              : Icons.timer_rounded,
                          color: currentUser.hasActiveVip
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF38BDF8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentUser.hasActiveVip
                              ? '👑 VIP: Sınırsız Match Haritası'
                              : '⏱️ Günlük Kalan: ${_matchMapRemainingSeconds ~/ 60} dk (VIP ile Sınırsız)',
                          style: TextStyle(
                            color: currentUser.hasActiveVip
                                ? const Color(0xFFFDE68A)
                                : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

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
                      children: [
                        ...['🔥 Bugün', '📍 En Yakın (< 10 km)', '⚡ Bu Hafta'].map((dateFilter) {
                          final isSelected = _selectedDateFilter == dateFilter;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_selectedDateFilter == dateFilter) {
                                  _selectedDateFilter = null;
                                } else {
                                  _selectedDateFilter = dateFilter;
                                  _showParking = false;
                                  _showGasStations = false;
                                  _selectedPoi = null;
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
                        }),
                        // 🅿️ OTOPARKLAR FİLTRE ÇİPİ (İBB İSPARK DESTEKLİ)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showParking = !_showParking;
                              if (_showParking) {
                                _showGasStations = false;
                                _selectedCategoryFilter = null;
                                _selectedDateFilter = null;
                                _selectedEvent = null;
                              }
                              if (!_showParking && _selectedPoi?.type == PoiType.parking) {
                                _selectedPoi = null;
                              }
                            });
                            if (_showParking) {
                              MapPoiService().fetchIbbParkingLots().then((_) {
                                if (mounted) setState(() {});
                              });
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _showParking
                                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)])
                                  : null,
                              color: _showParking ? null : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _showParking ? const Color(0xFF60A5FA) : Colors.white12,
                                width: _showParking ? 1.4 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _showParking
                                      ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                                      : Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_parking_rounded,
                                  size: 15,
                                  color: _showParking ? Colors.white : const Color(0xFF60A5FA),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  MapPoiService().isLoadingIbb
                                      ? 'İBB İspark Yükleniyor...'
                                      : (_showParking ? 'Yakın Otoparklar (${nearbyParkingLots.length})' : 'Otoparklar'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: _showParking ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                if (_showParking) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // ⛽ BENZİNLİKLER FİLTRE ÇİPİ (OPENSTREETMAP CANLI ENTEGRASYON)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showGasStations = !_showGasStations;
                              if (_showGasStations) {
                                _showParking = false;
                                _selectedCategoryFilter = null;
                                _selectedDateFilter = null;
                                _selectedEvent = null;
                              }
                              if (!_showGasStations && _selectedPoi?.type == PoiType.gasStation) {
                                _selectedPoi = null;
                              }
                            });
                            if (_showGasStations && userLat != null && userLng != null) {
                              MapPoiService().fetchOsmGasStations(lat: userLat, lng: userLng).then((_) {
                                if (mounted) setState(() {});
                              });
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _showGasStations
                                  ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF047857)])
                                  : null,
                              color: _showGasStations ? null : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _showGasStations ? const Color(0xFF34D399) : Colors.white12,
                                width: _showGasStations ? 1.4 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _showGasStations
                                      ? const Color(0xFF059669).withValues(alpha: 0.4)
                                      : Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_gas_station_rounded,
                                  size: 15,
                                  color: _showGasStations ? Colors.white : const Color(0xFF34D399),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  MapPoiService().isLoadingOsmGas
                                      ? 'Benzinlikler Yükleniyor...'
                                      : (_showGasStations ? 'Yakın Benzinlikler (${nearbyGasStations.length})' : 'Benzinlikler'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: _showGasStations ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                if (_showGasStations) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: eventService.categories.where((c) => c != 'Tümü' && c != 'Festival').map((category) {
                        final isSelected = _selectedCategoryFilter == category;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedCategoryFilter == category) {
                                _selectedCategoryFilter = null;
                              } else {
                                _selectedCategoryFilter = category;
                                _showParking = false;
                                _showGasStations = false;
                                _selectedPoi = null;
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
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              activeMatchUsers.isNotEmpty
                                  ? '${activeMatchUsers.length} Canlı'
                                  : 'Kullanıcı Aranıyor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentUser.isBoosted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9100)]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '⚡ ${currentUser.boostRemainingTime?.inMinutes ?? 60}dk Boost',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Hayalet Modu & Görünürlük Butonu (Tüm cihazlar ve Supabase ile canlı senkronize)
                    GestureDetector(
                      onTap: () async {
                        final newStatus = !currentUser.enableLocationSharing;
                        setState(() {
                          currentUser.enableLocationSharing = newStatus;
                        });
                        HapticFeedback.mediumImpact();
                        await radarService.updateGhostMode(newStatus);
                        eventService.notifyListenersPublic();
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

          // Sağ Alt Butonlar (⚡ Boost, Zoom ve Konumuma Git)
          Positioned(
            right: 16,
            bottom: (_selectedEvent != null || _selectedUser != null) ? 240 : 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚡ 1 SAATLİK RADAR BOOST BUTONU (VIP)
                GestureDetector(
                  onTap: () async {
                    final isBoosted = currentUser.isBoosted;
                    if (isBoosted) {
                      final rem = currentUser.boostRemainingTime;
                      final mins = rem != null ? rem.inMinutes : 60;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E1B18),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          content: Row(
                            children: [
                              const Text('⚡', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Harita Boostun Aktif! Kalan süre: $mins dakika. Profilin radardaki herkese en üstte gösteriliyor 👑',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    final canBoost = await eventService.canBoostToday();
                    if (!canBoost) {
                      if (!currentUser.hasActiveVip) {
                        VipPaywallSheet.show(
                          context,
                          initialFeature: VipFeature.mapBoost,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bugünkü 1 ücretsiz Boost hakkınızı kullandınız. Günde 5 adet 1 saatlik Boost için VIP\'e geçin! 👑'),
                            backgroundColor: Color(0xFF1E1E2E),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bugünkü 5 VIP Boost hakkınızın tamamını kullandınız. Gece 00:00\'da yenilenecektir.'),
                            backgroundColor: Color(0xFF1E1E2E),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }

                    final success = await eventService.triggerDailyBoost();
                    if (success && mounted) {
                      final isVip = currentUser.hasActiveVip;
                      final durText = isVip ? '1 saat' : '30 dakika';
                      final remaining = await eventService.getRemainingDailyBoosts();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E1B18),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          content: Row(
                            children: [
                              const Text('⚡', style: TextStyle(fontSize: 22)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Harita Boost Aktifleştirildi! Profilin $durText boyunca yakındaki tüm kullanıcılarda en üstte parlayacak! (Kalan hak: $remaining) 🚀',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: currentUser.isBoosted
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF2C2411), Color(0xFF1E190E)],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: currentUser.isBoosted ? 0.6 : 0.25),
                          blurRadius: currentUser.isBoosted ? 14 : 8,
                          spreadRadius: currentUser.isBoosted ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: currentUser.isBoosted ? Colors.black : const Color(0xFFFFD700),
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentUser.isBoosted
                              ? '${currentUser.boostRemainingTime?.inMinutes ?? 60}d'
                              : 'Boost',
                          style: TextStyle(
                            color: currentUser.isBoosted ? Colors.black : const Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.6), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      _checkPermissionAndGetLocation(forceCenter: true);
                      if (userLat != null && userLng != null) {
                        _mapController.move(LatLng(userLat, userLng), 14.5);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.my_location_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                  ),
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

          // 3.5 POI (OTOPARK & BENZİNLİK) BİLGİ KARTI
          if (_selectedPoi != null && _currentMapMode == MapMode.events)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _selectedPoi!.type == PoiType.parking
                        ? (_selectedPoi!.isFull
                            ? const Color(0xFFDC2626).withValues(alpha: 0.8)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.8))
                        : const Color(0xFF10B981).withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedPoi!.type == PoiType.parking
                              ? (_selectedPoi!.isFull
                                  ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                                  : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)])
                              : [const Color(0xFF059669), const Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_selectedPoi!.type == PoiType.parking
                                    ? (_selectedPoi!.isFull ? const Color(0xFFDC2626) : const Color(0xFF2563EB))
                                    : const Color(0xFF059669))
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _selectedPoi!.type == PoiType.parking
                            ? Icons.local_parking_rounded
                            : Icons.local_gas_station_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedPoi!.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedPoi!.isIbb) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _selectedPoi!.isFull
                                        ? const Color(0xFF7F1D1D)
                                        : const Color(0xFF1E3A8A),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _selectedPoi!.isFull
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF60A5FA),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: _selectedPoi!.isFull
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'İBB Canlı',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_selectedPoi!.type == PoiType.gasStation) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF064E3B),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF34D399),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_gas_station_rounded, color: Color(0xFF34D399), size: 10),
                                      SizedBox(width: 3),
                                      Text(
                                        'OSM Canlı',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPoi = null;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _selectedPoi!.description,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              if (_selectedPoi!.getFormattedDistance(userLat, userLng) != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.near_me_rounded, color: Color(0xFF60A5FA), size: 11),
                                      const SizedBox(width: 3),
                                      Text(
                                        _selectedPoi!.getFormattedDistance(userLat, userLng)!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (_selectedPoi!.feeOrCapacity != null)
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _selectedPoi!.isFull
                                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.5)
                                          : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedPoi!.feeOrCapacity!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _selectedPoi!.type == PoiType.parking
                                            ? (_selectedPoi!.isFull ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD))
                                            : const Color(0xFF6EE7B7),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  final mapsUrl =
                                      'https://www.google.com/maps/dir/?api=1&destination=${_selectedPoi!.latitude},${_selectedPoi!.longitude}';
                                  await UrlLauncherHelper.launchURL(mapsUrl);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_car_rounded, color: Colors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Yol Tarifi',
                                        style: TextStyle(
                                          color: Colors.white,
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
                        ],
                      ),
                    ),
                  ],
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
                  border: Border.all(
                    color: _selectedUser!.isBoosted
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF8B5CF6).withOpacity(0.35),
                    width: _selectedUser!.isBoosted ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedUser!.isBoosted
                          ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                          : Colors.black.withOpacity(0.45),
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
                                  if (_selectedUser!.isVerifiedBadgeVisible) ...[
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
                        final msgService = context.watch<MockMessageService>();
                        final matchService = context.watch<MockMatchService>();
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

          // 4. MATCH HARİTASI GÜNLÜK 1 SAAT KOTA KİLİT PANELİ (Ücretsiz Hesaplar İçin)
          if (_currentMapMode == MapMode.matchMap && !currentUser.hasActiveVip && _matchMapRemainingSeconds <= 0)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.85),
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                            ),
                            child: const Icon(Icons.timer_off_rounded, color: Color(0xFFF59E0B), size: 52),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Günlük 1 Saatlik Match Haritası Süreniz Doldu',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ücretsiz hesaplar günde 1 saat Match Haritası kullanabilir. Etkinlik haritası herkese sınırsız açıktır. 7/24 sınırsız radar ve eşleşme için VIP\'e geçebilirsiniz.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => VipPaywallSheet.show(context, initialFeature: VipFeature.mapBoost),
                            icon: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                            label: const Text('VIP\'e Geç (Sınırsız Radar 👑)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () {
                              _matchMapQuotaTimer?.cancel();
                              setState(() {
                                _currentMapMode = MapMode.events;
                              });
                            },
                            icon: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 16),
                            label: const Text('Ücretsiz Etkinlik Haritasına Dön', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
