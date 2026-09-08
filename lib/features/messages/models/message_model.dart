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
  final Map<String, String> reactions; // userId -> emoji (e.g. {'u1': '❤️'})
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? mediaUrl;
  final int? audioDurationSeconds;
  final String messageType; // 'text' | 'audio'

  MessageModel({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    Map<String, String>? reactions,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderName,
    this.mediaUrl,
    this.audioDurationSeconds,
    this.messageType = 'text',
  }) : reactions = reactions ?? {};

  bool get isRead => status == MessageStatus.read;
  bool get isAudio => messageType == 'audio' || (mediaUrl != null && mediaUrl!.isNotEmpty);

  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (var emoji in reactions.values) {
      if (emoji.isNotEmpty) {
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
    }
    return counts;
  }

  String? myReaction(String currentUserId) {
    final lowerId = currentUserId.toLowerCase().trim();
    for (var entry in reactions.entries) {
      if (entry.key.toLowerCase().trim() == lowerId) {
        return entry.value;
      }
    }
    return null;
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    Map<String, String>? reactions,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderName,
    String? mediaUrl,
    int? audioDurationSeconds,
    String? messageType,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      reactions: reactions ?? Map<String, String>.from(this.reactions),
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      messageType: messageType ?? this.messageType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': text,
      'created_at': timestamp.toIso8601String(),
      'status': status.name,
      'is_read': status == MessageStatus.read,
      'reactions': reactions,
      'reply_to_id': replyToMessageId,
      'reply_to_text': replyToText,
      'reply_to_sender_name': replyToSenderName,
      'media_url': mediaUrl,
      'audio_duration': audioDurationSeconds,
      'message_type': messageType,
    };
  }

  static ({String cleanText, String? replySender, String? replyText, String? mediaUrl, int? audioDuration, String messageType}) parseEncodedContent(String rawContent) {
    String currentText = rawContent;
    String? replySender;
    String? replyText;
    String? mediaUrl;
    int? audioDuration;
    String messageType = 'text';

    if (currentText.startsWith('[reply:')) {
      final closeBracket = currentText.indexOf(']');
      if (closeBracket > 7) {
        final inner = currentText.substring(7, closeBracket);
        final splitColon = inner.indexOf(':');
        if (splitColon >= 0) {
          replySender = inner.substring(0, splitColon);
          replyText = inner.substring(splitColon + 1);
        } else {
          replyText = inner;
        }
        currentText = currentText.substring(closeBracket + 1).trim();
      }
    }

    if (currentText.startsWith('[audio:')) {
      final closeBracket = currentText.indexOf(']');
      if (closeBracket > 7) {
        final inner = currentText.substring(7, closeBracket);
        final lastColon = inner.lastIndexOf(':');
        if (lastColon >= 0) {
          mediaUrl = inner.substring(0, lastColon);
          audioDuration = int.tryParse(inner.substring(lastColon + 1));
        } else {
          mediaUrl = inner;
        }
        messageType = 'audio';
        currentText = '🎤 Sesli Mesaj';
      }
    }

    return (
      cleanText: currentText,
      replySender: replySender,
      replyText: replyText,
      mediaUrl: mediaUrl,
      audioDuration: audioDuration,
      messageType: messageType,
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    MessageStatus parsedStatus = MessageStatus.sent;
    if (map['status'] != null) {
      parsedStatus = MessageStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => map['is_read'] == true ? MessageStatus.read : MessageStatus.sent,
      );
    } else if (map['is_read'] == true) {
      parsedStatus = MessageStatus.read;
    }

    final reactionsRaw = map['reactions'];
    final reactionsMap = <String, String>{};
    if (reactionsRaw is Map) {
      reactionsRaw.forEach((k, v) {
        if (k != null && v != null) {
          reactionsMap[k.toString()] = v.toString();
        }
      });
    }

    final rawContent = map['content']?.toString() ?? map['message']?.toString() ?? map['text']?.toString() ?? '';
    final parsed = parseEncodedContent(rawContent);

    final replyId = map['reply_to_id']?.toString();
    final replyText = map['reply_to_text']?.toString() ?? parsed.replyText;
    final replySender = map['reply_to_sender_name']?.toString() ?? parsed.replySender;
    final mediaUrl = map['media_url']?.toString() ?? parsed.mediaUrl;
    final audioDuration = map['audio_duration'] is int
        ? map['audio_duration'] as int
        : (int.tryParse(map['audio_duration']?.toString() ?? '') ?? parsed.audioDuration);
    final messageType = map['message_type']?.toString() ?? (parsed.messageType != 'text' ? parsed.messageType : (mediaUrl != null && mediaUrl.isNotEmpty ? 'audio' : 'text'));

    return MessageModel(
      id: map['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: map['sender_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString(),
      text: parsed.cleanText.isNotEmpty ? parsed.cleanText : rawContent,
      timestamp: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now() : DateTime.now()),
      status: parsedStatus,
      reactions: reactionsMap,
      replyToMessageId: replyId,
      replyToText: replyText,
      replyToSenderName: replySender,
      mediaUrl: mediaUrl,
      audioDurationSeconds: audioDuration,
      messageType: messageType,
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
    this.isOnline = false,
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
      isOnline: map['is_online'] == true,
      lastSeen: map['last_seen'] != null ? DateTime.tryParse(map['last_seen'].toString()) : null,
      isArchived: map['is_archived'] == true,
      isMuted: map['is_muted'] == true,
    );
  }
}
