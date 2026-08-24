import 'user_model.dart';

enum MatchRequestStatus { pending, accepted, rejected }

class MatchRequest {
  final String id;
  final UserModel fromUser;
  final UserModel toUser;
  final String eventId;
  MatchRequestStatus status;

  MatchRequest({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.eventId,
    this.status = MatchRequestStatus.pending,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_user': fromUser.toMap(),
      'to_user': toUser.toMap(),
      'event_id': eventId,
      'status': status.name,
    };
  }

  factory MatchRequest.fromMap(Map<String, dynamic> map) {
    return MatchRequest(
      id: map['id']?.toString() ?? '',
      fromUser: UserModel.fromMap(Map<String, dynamic>.from(map['from_user'] ?? {})),
      toUser: UserModel.fromMap(Map<String, dynamic>.from(map['to_user'] ?? {})),
      eventId: map['event_id']?.toString() ?? '',
      status: MatchRequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MatchRequestStatus.pending,
      ),
    );
  }
}

