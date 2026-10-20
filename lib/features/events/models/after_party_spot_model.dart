import 'dart:math';

class AfterPartySpotModel {
  final String id;
  final String eventId;
  final String name;
  final String category; // 'Pub & Bira', 'Kokteyl & Bar', 'Gece Kulübü', 'Gece Atıştırmalığı'
  final String address;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final int walkingMinutes;
  final String? note;

  const AfterPartySpotModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.walkingMinutes,
    this.note,
  });

  factory AfterPartySpotModel.fromMap(Map<String, dynamic> map, {double? eventLat, double? eventLng}) {
    final lat = (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : 41.042;
    final lng = (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : 28.995;
    
    double dist = 400;
    if (eventLat != null && eventLng != null) {
      dist = _calculateDistance(eventLat, eventLng, lat, lng);
    }
    final mins = max(1, (dist / 80).round()); // ~80m per minute walking

    return AfterPartySpotModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Mekan Önerisi',
      category: map['category']?.toString() ?? 'Bar & Pub',
      address: map['address']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      distanceMeters: dist,
      walkingMinutes: mins,
      note: map['note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'note': note,
    };
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // meters
  }
}
