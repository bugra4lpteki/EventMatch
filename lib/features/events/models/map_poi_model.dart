import 'package:geolocator/geolocator.dart';

enum PoiType {
  parking,
  gasStation,
}

class MapPoiModel {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final PoiType type;
  final String brandOrOperator;
  final String? feeOrCapacity;
  final int? totalCapacity;
  final int? emptyCapacity;
  final String? workHours;
  final String? district;
  final bool isIbb;

  const MapPoiModel({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.brandOrOperator,
    this.feeOrCapacity,
    this.totalCapacity,
    this.emptyCapacity,
    this.workHours,
    this.district,
    this.isIbb = false,
  });

  bool get isFull => emptyCapacity != null && emptyCapacity == 0;

  double? getDistanceInKm(double? userLat, double? userLng) {
    if (userLat == null || userLng == null) return null;
    final meters = Geolocator.distanceBetween(userLat, userLng, latitude, longitude);
    return meters / 1000.0;
  }

  String? getFormattedDistance(double? userLat, double? userLng) {
    final dist = getDistanceInKm(userLat, userLng);
    if (dist == null) return null;
    if (dist < 1.0) {
      final meters = (dist * 1000).round();
      return '$meters m';
    }
    return '${dist.toStringAsFixed(1)} km';
  }
}
