import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'mock_event_service.dart';
import '../models/user_model.dart';

class LocationRadarService extends ChangeNotifier {
  final MockEventService _eventService;
  bool _isRadarActive = false;
  List<UserModel> _nearbyUsers = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _hasSentNotification = false;
  double _radarDistanceKm = 10.0;
  Position? _lastPosition;

  LocationRadarService(this._eventService);

  bool get isRadarActive => _isRadarActive;
  int get nearbyUsersCount => _nearbyUsers.length;
  List<UserModel> get nearbyUsers => _nearbyUsers;
  double get radarDistanceKm => _radarDistanceKm;

  void updateRadarDistance(double distance) {
    _radarDistanceKm = distance;
    notifyListeners();
    if (_isRadarActive && _lastPosition != null) {
      _handlePositionUpdate(_lastPosition!);
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _isRadarActive = false;
      notifyListeners();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _isRadarActive = false;
        notifyListeners();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _isRadarActive = false;
      notifyListeners();
      return;
    }

    // Permission is granted, activate radar
    _isRadarActive = true;
    notifyListeners();

    // Pil tasarrufu için distanceFilter ekleyerek her an tetiklenmeyi engelliyoruz (örn: en az 30 metre hareket ettiğinde tetiklenir)
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium, // Medium accuracy saves battery
      distanceFilter: 30, 
    );

    // Initial position fetch immediately
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      _handlePositionUpdate(position);
    } catch (e) {
      debugPrint("İlk konum alınamadı: $e");
    }

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _handlePositionUpdate(position);
    });
  }

  void _stopRadar() {
    _isRadarActive = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _nearbyUsers = [];
    _hasSentNotification = false; 
    notifyListeners();
  }

  void _handlePositionUpdate(Position position) {
    _lastPosition = position;

    List<UserModel> nearby = [];
    final allEvents = _eventService.getAdminEvents();
    final Set<String> addedUserIds = {};

    for (var event in allEvents) {
      for (var user in event.attendees) {
        if (user.latitude != null && user.longitude != null && user.enableLocationSharing && !addedUserIds.contains(user.id)) {
          double distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            user.latitude!,
            user.longitude!,
          );

          if (distanceInMeters < _radarDistanceKm * 1000) {
            nearby.add(user);
            addedUserIds.add(user.id);
          }
        }
      }
    }

    _nearbyUsers = nearby;
    notifyListeners();

    if (_nearbyUsers.isNotEmpty && !_hasSentNotification) {
      NotificationService.showRadarNotification(
        "Radar Tespit Etti! 📡", 
        "Yakınınızda eşleşebileceğiniz ${_nearbyUsers.length} kişi var! Göz atmak ister misin?"
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
