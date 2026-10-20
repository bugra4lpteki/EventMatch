import 'dart:math';

class AfterPartySpotModel {
  final String id;
  final String eventId;
  final String name;
  final String category; // 'Pub / Bira', 'Kokteyl & Bar', 'Gece Kulübü', 'Gece Atıştırmalığı', 'Toplanma Noktası'
  final String address;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final int walkingMinutes;
  final String? note;
  final bool isUserCreated;
  final String? createdByName;
  final List<String> attendeeNames;

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
    this.isUserCreated = false,
    this.createdByName,
    this.attendeeNames = const [],
  });

  AfterPartySpotModel copyWith({
    String? id,
    String? eventId,
    String? name,
    String? category,
    String? address,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    int? walkingMinutes,
    String? note,
    bool? isUserCreated,
    String? createdByName,
    List<String>? attendeeNames,
  }) {
    return AfterPartySpotModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      note: note ?? this.note,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      createdByName: createdByName ?? this.createdByName,
      attendeeNames: attendeeNames ?? this.attendeeNames,
    );
  }

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
      name: map['name']?.toString() ?? 'After Party Mekanı',
      category: map['category']?.toString() ?? 'Bar & Pub',
      address: map['address']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      distanceMeters: dist,
      walkingMinutes: mins,
      note: map['note']?.toString(),
      isUserCreated: map['is_user_created'] == true,
      createdByName: map['created_by_name']?.toString(),
      attendeeNames: (map['attendee_names'] is List)
          ? (map['attendee_names'] as List).map((e) => e.toString()).toList()
          : [],
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
      'is_user_created': isUserCreated,
      'created_by_name': createdByName,
      'attendee_names': attendeeNames,
    };
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // meters
  }
}
