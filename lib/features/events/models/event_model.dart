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
}
