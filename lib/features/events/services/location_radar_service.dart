import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'mock_event_service.dart';
import '../models/user_model.dart';

class LocationRadarService extends ChangeNotifier {
  final MockEventService _eventService;
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isRadarActive = false;
  List<UserModel> _nearbyUsers = [];
  final Map<String, UserModel> _liveRealtimeUsers = {};
  StreamSubscription<Position>? _positionStreamSubscription;
  RealtimeChannel? _radarChannel;
  Timer? _pingTimer;
  Timer? _dbSyncTimer;
  bool _hasSentNotification = false;
  double _radarDistanceKm = 50.0; // Default broad coverage for events & testing
  Position? _lastPosition;

  LocationRadarService(this._eventService);

  bool get isRadarActive => _isRadarActive;
  int get nearbyUsersCount => _nearbyUsers.length;
  List<UserModel> get nearbyUsers => _nearbyUsers;
  double get radarDistanceKm => _radarDistanceKm;
  Position? get currentPosition => _lastPosition;

  String get currentUserId {
    return _supabase.auth.currentUser?.id ?? _eventService.currentUser.id;
  }

  void updateRadarDistance(double distance) {
    _radarDistanceKm = distance;
    notifyListeners();
    if (_isRadarActive && _lastPosition != null) {
      _recalculateNearbyUsers();
    }
  }

  Future<void> toggleRadar(bool val) async {
    if (val) {
      await _startRadar();
    } else {
      _stopRadar();
    }
  }

  Future<void> _startRadar() async {
    _isRadarActive = true;
    notifyListeners();

    // 1. Konum belirleme (Mobil GPS veya PC/Desktop için yedek koordinat)
    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 4));
        }
      }
    } catch (e) {
      debugPrint('[Radar] GPS alınırken hata/zaman aşımı: $e. Yedek koordinat kullanılıyor.');
    }

    // GPS bulunamazsa veya PC/Masaüstü ortamında varsayılan İstanbul/Etkinlik koordinatları
    position ??= Position(
      latitude: _eventService.currentUser.latitude ?? 41.0082,
      longitude: _eventService.currentUser.longitude ?? 28.9784,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

    _lastPosition = position;

    // 2. Kullanıcının mevcut koordinatlarını yerel ve Supabase'de güncelle
    _eventService.currentUser.latitude = position.latitude;
    _eventService.currentUser.longitude = position.longitude;
    _syncMyCoordinatesToCloud(position);

    // 3. Supabase Realtime Radar Kanalına Abone Ol
    _subscribeToRadarRealtimeChannel();

    // 4. Periyodik olarak canlı radar sinyali yayınla ve veritabanını tara
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isRadarActive && _lastPosition != null) {
        _broadcastRadarPresence(isPing: true);
      }
    });

    _dbSyncTimer?.cancel();
    _dbSyncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_isRadarActive) {
        _fetchActiveUsersFromCloud();
      }
    });

    // İlk taramayı anında yap
    _broadcastRadarPresence(isPing: true);
    _fetchActiveUsersFromCloud();
    _recalculateNearbyUsers();

    // 5. Konum akışı dinleyicisi
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 20,
      );
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position newPos) {
        _lastPosition = newPos;
        _eventService.currentUser.latitude = newPos.latitude;
        _eventService.currentUser.longitude = newPos.longitude;
        _syncMyCoordinatesToCloud(newPos);
        _recalculateNearbyUsers();
        _broadcastRadarPresence(isPing: true);
      });
    } catch (_) {}
  }

  void _stopRadar() {
    _isRadarActive = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _dbSyncTimer?.cancel();
    _dbSyncTimer = null;
    
    try {
      _radarChannel?.unsubscribe();
      _radarChannel = null;
    } catch (_) {}

    _liveRealtimeUsers.clear();
    _nearbyUsers = [];
    _hasSentNotification = false;
    notifyListeners();
  }

  Future<void> _syncMyCoordinatesToCloud(Position pos) async {
    try {
      final uid = currentUserId;
      if (uid.isNotEmpty) {
        await _supabase.from('users').upsert({
          'id': uid,
          'name': _eventService.currentUser.name,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'city': _eventService.currentUser.city ?? 'İstanbul',
          'about_me': _eventService.currentUser.aboutMe ?? '',
          'avatar_url': _eventService.currentUser.avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[Radar] Koordinat senkronizasyon hatası: $e');
    }
  }

  void _subscribeToRadarRealtimeChannel() {
    try {
      _radarChannel?.unsubscribe();
      _radarChannel = _supabase.channel('eventmatch_radar_stream');

      _radarChannel!
          .onBroadcast(
            event: 'radar_ping',
            callback: (payload) {
              _handleIncomingRadarPayload(payload, isPing: true);
            },
          )
          .onBroadcast(
            event: 'radar_pong',
            callback: (payload) {
              _handleIncomingRadarPayload(payload, isPing: false);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 [RADAR REALTIME] Kanal durumu: $status');
            if (status == RealtimeSubscribeStatus.subscribed) {
              _broadcastRadarPresence(isPing: true);
            }
          });
    } catch (e) {
      debugPrint('[Radar] Realtime kanal abonelik hatası: $e');
    }
  }

  void _broadcastRadarPresence({bool isPing = true}) {
    if (!_isRadarActive || _lastPosition == null || _radarChannel == null) return;

    try {
      final user = _eventService.currentUser;
      final payload = {
        'user_id': currentUserId,
        'user_name': user.name,
        'username': user.username ?? '',
        'avatar_url': user.avatarUrl,
        'avatar_urls': user.avatarUrls,
        'city': user.city ?? 'İstanbul',
        'about_me': user.aboutMe ?? 'Müzik ve festival sever 🎶',
        'age': user.age ?? '24',
        'gender': user.gender,
        'interests': user.tags,
        'points': user.points,
        'latitude': _lastPosition!.latitude,
        'longitude': _lastPosition!.longitude,
        'is_radar_active': true,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      _radarChannel?.sendBroadcastMessage(
        event: isPing ? 'radar_ping' : 'radar_pong',
        payload: payload,
      );
    } catch (e) {
      debugPrint('[Radar] Sinyal yayınlama hatası: $e');
    }
  }

  void _handleIncomingRadarPayload(Map<String, dynamic> payload, {required bool isPing}) {
    try {
      final remoteUserId = payload['user_id']?.toString() ?? '';
      final remoteUserName = payload['user_name']?.toString() ?? '';

      // Kendi cihazımızın sinyalini atla
      if (remoteUserId.isEmpty ||
          remoteUserId.toLowerCase() == currentUserId.toLowerCase() ||
          remoteUserName.toLowerCase() == _eventService.currentUser.name.toLowerCase()) {
        return;
      }

      final double? remoteLat = double.tryParse(payload['latitude']?.toString() ?? '');
      final double? remoteLng = double.tryParse(payload['longitude']?.toString() ?? '');

      if (remoteLat == null || remoteLng == null) return;

      // Mesafe hesapla
      double distanceInMeters = 0;
      if (_lastPosition != null) {
        distanceInMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          remoteLat,
          remoteLng,
        );
      }

      // Radar menzili içindeyse ekle
      if (distanceInMeters <= _radarDistanceKm * 1000 || distanceInMeters == 0) {
        final remoteUser = UserModel(
          id: remoteUserId,
          name: remoteUserName,
          username: payload['username']?.toString(),
          avatarUrl: payload['avatar_url']?.toString() ?? '',
          avatarUrls: List<String>.from(payload['avatar_urls'] ?? []),
          city: payload['city']?.toString() ?? 'İstanbul',
          aboutMe: payload['about_me']?.toString() ?? 'Müzik ve festival sever',
          gender: payload['gender']?.toString(),
          points: int.tryParse(payload['points']?.toString() ?? '0') ?? 0,
          latitude: remoteLat,
          longitude: remoteLng,
          tags: List<String>.from(payload['interests'] ?? []),
          enableLocationSharing: true,
        );

        _liveRealtimeUsers[remoteUserId.toLowerCase()] = remoteUser;
        _recalculateNearbyUsers();

        // Eğer karşı taraf ping attıysa biz de hemen cevap veriyoruz (pong)
        if (isPing) {
          _broadcastRadarPresence(isPing: false);
        }
      }
    } catch (e) {
      debugPrint('[Radar] Gelen sinyal işleme hatası: $e');
    }
  }

  Future<void> _fetchActiveUsersFromCloud() async {
    try {
      final currentId = currentUserId.toLowerCase();
      final currentName = _eventService.currentUser.name.toLowerCase();

      // Supabase 'users' tablosundaki kullanıcıları çek
      final List<dynamic> rows = await _supabase.from('users').select();

      for (var row in rows) {
        final uid = row['id']?.toString() ?? '';
        final uname = row['name']?.toString() ?? '';

        if (uid.isEmpty || uid.toLowerCase() == currentId || uname.toLowerCase() == currentName) {
          continue;
        }

        final double? uLat = double.tryParse(row['latitude']?.toString() ?? '');
        final double? uLng = double.tryParse(row['longitude']?.toString() ?? '');

        if (uLat != null && uLng != null) {
          double dist = 0;
          if (_lastPosition != null) {
            dist = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              uLat,
              uLng,
            );
          }

          if (dist <= _radarDistanceKm * 1000 || dist == 0) {
            _liveRealtimeUsers[uid.toLowerCase()] = UserModel(
              id: uid,
              name: uname,
              username: row['username']?.toString(),
              avatarUrl: row['avatar_url']?.toString() ?? '',
              avatarUrls: row['avatar_url'] != null ? [row['avatar_url'].toString()] : [],
              city: row['city']?.toString() ?? 'İstanbul',
              aboutMe: row['about_me']?.toString() ?? 'Festival ve konser tutkunu',
              latitude: uLat,
              longitude: uLng,
              enableLocationSharing: true,
              tags: row['interests'] != null ? List<String>.from(row['interests']) : ['Müzik', 'Festival'],
            );
          }
        }
      }
      _recalculateNearbyUsers();
    } catch (e) {
      debugPrint('[Radar] Veritabanı kullanıcı tarama hatası: $e');
    }
  }

  void _recalculateNearbyUsers() {
    final Map<String, UserModel> merged = {};
    final myId = currentUserId.toLowerCase();
    final myName = _eventService.currentUser.name.toLowerCase();

    // 1. Canlı Realtime & Cloud'dan tespit edilen gerçek kullanıcılar
    for (var u in _liveRealtimeUsers.values) {
      if (u.id.toLowerCase() != myId && u.name.toLowerCase() != myName) {
        merged[u.id.toLowerCase()] = u;
      }
    }

    // 2. Yerel etkinlik katılımcılarından koordinatları uyanlar
    final allEvents = _eventService.getAdminEvents();
    for (var event in allEvents) {
      for (var user in event.attendees) {
        final uid = user.id.toLowerCase();
        final uname = user.name.toLowerCase();

        if (uid != myId && uname != myName && !merged.containsKey(uid)) {
          if (user.latitude != null && user.longitude != null && user.enableLocationSharing) {
            if (_lastPosition != null) {
              double dist = Geolocator.distanceBetween(
                _lastPosition!.latitude,
                _lastPosition!.longitude,
                user.latitude!,
                user.longitude!,
              );
              if (dist <= _radarDistanceKm * 1000) {
                merged[uid] = user;
              }
            } else {
              merged[uid] = user;
            }
          }
        }
      }
    }

    _nearbyUsers = merged.values.toList();
    notifyListeners();

    if (_nearbyUsers.isNotEmpty && !_hasSentNotification) {
      NotificationService.showRadarNotification(
        "Radar Tespit Etti! 📡",
        "Yakınınızda eşleşebileceğiniz ${_nearbyUsers.length} kişi var! Göz atmak ister misin?",
      );
      _hasSentNotification = true;
    }
  }

  @override
  void dispose() {
    _stopRadar();
    super.dispose();
  }
}
