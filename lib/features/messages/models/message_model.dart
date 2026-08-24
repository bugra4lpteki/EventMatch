import '../../events/models/user_model.dart';
import '../../events/models/event_model.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String? receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': text,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: map['sender_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString(),
      text: map['content']?.toString() ?? map['message']?.toString() ?? map['text']?.toString() ?? '',
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now() : DateTime.now()),
      isRead: map['is_read'] == true,
    );
  }
}

class ChatModel {
  String id;
  final UserModel participant;
  final bool isEventBased;
  final EventModel? relatedEvent;
  final List<MessageModel> messages;
  int unreadCount;
  final DateTime? expiresAt;

  ChatModel({
    required this.id,
    required this.participant,
    this.isEventBased = false,
    this.relatedEvent,
    required this.messages,
    this.unreadCount = 0,
    this.expiresAt,
  });

  MessageModel? get lastMessage {
    if (messages.isEmpty) return null;
    return messages.last;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participant': participant.toMap(),
      'is_event_based': isEventBased,
      'messages': messages.map((m) => m.toMap()).toList(),
      'unread_count': unreadCount,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    final participantMap = Map<String, dynamic>.from(map['participant'] ?? {});
    final messagesList = (map['messages'] as List? ?? [])
        .map((m) => MessageModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    return ChatModel(
      id: map['id']?.toString() ?? '',
      participant: UserModel.fromMap(participantMap),
      isEventBased: map['is_event_based'] == true,
      messages: messagesList,
      unreadCount: map['unread_count'] is int ? map['unread_count'] : 0,
      expiresAt: map['expires_at'] != null ? DateTime.tryParse(map['expires_at'].toString()) : null,
    );
  }
}


