class EventReviewModel {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final int rating; // 1 to 5
  final String comment;
  final DateTime createdAt;

  const EventReviewModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory EventReviewModel.fromMap(Map<String, dynamic> map) {
    return EventReviewModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? 'Etkinlik Sever',
      userAvatar: map['user_avatar']?.toString(),
      rating: (map['rating'] is int)
          ? map['rating'] as int
          : int.tryParse(map['rating']?.toString() ?? '5') ?? 5,
      comment: map['comment']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
