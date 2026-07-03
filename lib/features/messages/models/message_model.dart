import '../../events/models/user_model.dart';
import '../../events/models/event_model.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });
}

class ChatModel {
  final String id;
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
}
