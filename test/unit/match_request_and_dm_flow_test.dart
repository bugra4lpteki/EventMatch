import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/events/models/match_request.dart';
import 'package:event_match/features/events/models/user_model.dart';
import 'package:event_match/features/messages/models/message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Match Request & DM Creation Flow Tests', () {
    final senderUser = UserModel(
      id: 'user_sender_111',
      name: 'Ahmet Yılmaz',
      username: 'ahmety',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde',
      isVerified: true,
    );

    final receiverUser = UserModel(
      id: 'user_receiver_222',
      name: 'Buğra Alptekin',
      username: 'bugra4lptekii',
      avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61',
      isVerified: true,
    );

    test('MatchRequest successfully stores initial message note', () {
      const note = 'Konserde birlikte eğlenelim mi?';
      final request = MatchRequest(
        id: '1001',
        fromUser: senderUser,
        toUser: receiverUser,
        eventId: 'event_rock_fest',
        message: note,
      );

      expect(request.id, equals('1001'));
      expect(request.fromUser.id, equals('user_sender_111'));
      expect(request.toUser.id, equals('user_receiver_222'));
      expect(request.message, equals(note));
      expect(request.eventId, equals('event_rock_fest'));
    });

    test('ChatModel is properly created for incoming DM with note', () {
      const initialMessage = 'Haritadan selam!';
      final firstMsg = MessageModel(
        id: 'msg_initial_1',
        senderId: senderUser.id,
        receiverId: receiverUser.id,
        text: initialMessage,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );

      final chat = ChatModel(
        id: 'chat_${senderUser.id}',
        participant: senderUser,
        messages: [firstMsg],
        unreadCount: 1,
      );

      expect(chat.participant.id, equals('user_sender_111'));
      expect(chat.messages.length, equals(1));
      expect(chat.lastMessage?.text, equals(initialMessage));
      expect(chat.unreadCount, equals(1));
    });

    test('Partner identification logic for direct messages works symmetrically', () {
      const currentId = 'user_receiver_222';

      // Incoming direct message (partner is sender)
      final incoming = {
        'sender_id': 'user_sender_111',
        'receiver_id': currentId,
        'content': 'Merhaba!',
      };

      final s1 = (incoming['sender_id'] ?? '').toString().toLowerCase();
      final r1 = (incoming['receiver_id'] ?? '').toString().toLowerCase();
      final p1 = s1 == currentId.toLowerCase() ? r1 : s1;

      expect(p1, equals('user_sender_111'));

      // Outgoing direct message (partner is receiver)
      final outgoing = {
        'sender_id': currentId,
        'receiver_id': 'user_sender_111',
        'content': 'Selam hoş geldin!',
      };

      final s2 = (outgoing['sender_id'] ?? '').toString().toLowerCase();
      final r2 = (outgoing['receiver_id'] ?? '').toString().toLowerCase();
      final p2 = s2 == currentId.toLowerCase() ? r2 : s2;

      expect(p2, equals('user_sender_111'));
    });

    test('Deduplication prevents duplicate match requests from the same user', () {
      final list = <MatchRequest>[];
      final seen = <String>{};

      void addRequest(MatchRequest req) {
        final idKey = req.fromUser.id.toLowerCase();
        final nameKey = '${req.fromUser.id}_${req.fromUser.name}'.toLowerCase();
        if (!seen.contains(nameKey) && !seen.contains(idKey)) {
          seen.add(nameKey);
          seen.add(idKey);
          list.add(req);
        }
      }

      addRequest(MatchRequest(id: '1', fromUser: senderUser, toUser: receiverUser, message: 'İlk mesaj', eventId: 'event_1'));
      addRequest(MatchRequest(id: '2', fromUser: senderUser, toUser: receiverUser, message: 'Tekrar mesaj', eventId: 'event_1'));

      expect(list.length, equals(1));
      expect(list.first.message, equals('İlk mesaj'));
    });

    test('Accepting request resolves mutual match and preserves message in chat', () {
      final request = MatchRequest(
        id: '500',
        fromUser: senderUser,
        toUser: receiverUser,
        message: 'Birlikte gidelim!',
        eventId: 'event_1',
      );

      final newChat = ChatModel(
        id: 'chat_${request.fromUser.id}',
        participant: request.fromUser,
        messages: request.message != null && request.message!.isNotEmpty
            ? [
                MessageModel(
                  id: 'msg_first',
                  senderId: request.fromUser.id,
                  receiverId: receiverUser.id,
                  text: request.message!,
                  timestamp: DateTime.now(),
                  status: MessageStatus.delivered,
                )
              ]
            : [],
      );

      expect(newChat.messages.length, equals(1));
      expect(newChat.messages.first.text, equals('Birlikte gidelim!'));
      expect(newChat.participant.name, equals('Ahmet Yılmaz'));
    });
  });
}
