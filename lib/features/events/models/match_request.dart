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
}
