import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';
import '../models/chat_message_model.dart';

class RealtimeMessagingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<ChatMessageModel>> getChatStream(String currentUserId, String otherUserId) {
    try {
      return _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .map((maps) {
            final filtered = maps.where((m) {
              final sender = m['sender_id']?.toString();
              final receiver = m['receiver_id']?.toString();
              return (sender == currentUserId && receiver == otherUserId) ||
                     (sender == otherUserId && receiver == currentUserId);
            }).toList();

            return filtered.map((m) {
              final isMe = m['sender_id']?.toString() == currentUserId;
              return ChatMessageModel(
                id: m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                senderId: m['sender_id']?.toString() ?? '',
                receiverId: m['receiver_id']?.toString() ?? '',
                message: m['content']?.toString() ?? m['message']?.toString() ?? '',
                timestamp: m['created_at'] != null ? DateTime.parse(m['created_at']) : DateTime.now(),
                isMe: isMe,
              );
            }).toList();
          });
    } catch (e) {
      debugPrint('[RealtimeMessaging] Stream error: $e');
      return const Stream.empty();
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String messageText,
  }) async {
    if (messageText.trim().isEmpty) return;

    try {
      await _supabase.from('messages').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': messageText.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Local push notification test trigger
      NotificationService().showMessageNotification(senderName, messageText.trim());
    } catch (e) {
      debugPrint('[RealtimeMessaging] Send error: $e');
    }
  }
}
