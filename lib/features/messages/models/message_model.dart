import '../../events/models/user_model.dart';
import '../../events/models/event_model.dart';

enum MessageStatus {
  sending,   // Saat ikonu / Gönderiliyor
  sent,      // Tek gri tık (Sunucuya ulaştı)
  delivered, // Çift gri tık (Karşı cihaza iletildi)
  read,      // Çift mavi tık (Karşı taraf okudu)
}

class MessageModel {
  final String id;
  final String senderId;
  final String? receiverId;
  final String text;
  final DateTime timestamp;
  MessageStatus status;

  MessageModel({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  bool get isRead => status == MessageStatus.read;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': text,
      'created_at': timestamp.toIso8601String(),
      'status': status.name,
      'is_read': status == MessageStatus.read,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    MessageStatus parsedStatus = MessageStatus.sent;
    if (map['status'] != null) {
      parsedStatus = MessageStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MessageStatus.sent,
      );
    } else if (map['is_read'] == true) {
      parsedStatus = MessageStatus.read;
    }

    return MessageModel(
      id: map['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: map['sender_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString(),
      text: map['content']?.toString() ?? map['message']?.toString() ?? map['text']?.toString() ?? '',
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now() : DateTime.now()),
      status: parsedStatus,
    );
  }
}

class ChatModel {
  String id;
  final UserModel participant;
  final bool isEventBased;
  final EventModel? relatedEvent;
  List<MessageModel> messages;
  int unreadCount;
  final DateTime? expiresAt;
  bool isOnline;
  DateTime? lastSeen;
  bool isArchived;
  bool isMuted;

  ChatModel({
    required this.id,
    required this.participant,
    this.isEventBased = false,
    this.relatedEvent,
    required this.messages,
    this.unreadCount = 0,
    this.expiresAt,
    this.isOnline = true,
    this.lastSeen,
    this.isArchived = false,
    this.isMuted = false,
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
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'is_archived': isArchived,
      'is_muted': isMuted,
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
      isOnline: map['is_online'] != false,
      lastSeen: map['last_seen'] != null ? DateTime.tryParse(map['last_seen'].toString()) : null,
      isArchived: map['is_archived'] == true,
      isMuted: map['is_muted'] == true,
    );
  }
}
