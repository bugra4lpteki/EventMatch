import 'package:flutter/foundation.dart';
import 'user_model.dart';

class EventModel {
  final String id;
  final String title;
  final String category;
  final String location;
  final DateTime dateTime;
  final String description;
  final String imageUrl;
  final List<UserModel> attendees;
  final double? latitude;
  final double? longitude;
  bool isActive;

  EventModel({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.dateTime,
    required this.description,
    required this.imageUrl,
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.atmosphere = 'Sakin',
    this.isPopular = false,
    List<UserModel>? attendees,
  }) : attendees = attendees ?? [];

  final String atmosphere;
  final bool isPopular;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    try {
      return EventModel(
        id: json['id']?.toString() ?? UniqueKey().toString(),
        title: json['title']?.toString() ?? 'İsimsiz Etkinlik',
        category: json['type']?.toString() ?? 'Genel',
        location: json['city'] != null && json['venue'] != null 
            ? '${json['venue']}, ${json['city']}' 
            : json['venue']?.toString() ?? json['city']?.toString() ?? 'Bilinmiyor',
        dateTime: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
        description: json['description']?.toString() ?? '',
        imageUrl: json['image_url']?.toString() ?? '',
        latitude: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
        longitude: json['lng'] != null ? double.tryParse(json['lng'].toString()) : null,
        isPopular: json['tag']?.toString().toLowerCase().contains('popüler') ?? false,
        atmosphere: json['tag']?.toString() ?? 'Canlı',
      );
    } catch (e) {
      debugPrint('EventModel fromJson error: $e');
      rethrow;
    }
  }
}
