import 'user_model.dart';

enum CarpoolType { offer, request }

class CarpoolModel {
  final String id;
  final String eventId;
  final UserModel creator;
  final CarpoolType type;
  final String? note;
  final int capacity; // Total seats if offer, 0 if request
  final List<UserModel> participants;
  final DateTime createdAt;

  CarpoolModel({
    required this.id,
    required this.eventId,
    required this.creator,
    required this.type,
    this.note,
    this.capacity = 0,
    List<UserModel>? participants,
    DateTime? createdAt,
  })  : participants = participants ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get availableSeats => capacity - participants.length;
}
