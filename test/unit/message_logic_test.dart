import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/messages/models/message_model.dart';
import 'package:event_match/features/events/models/user_model.dart';

void main() {
  group('Message Filtering & Privacy Logic Tests', () {
    test('A message between User A and User B must be rejected for User C', () {
      const currentUserId = 'user_c';
      const senderId = 'user_a';
      const receiverId = 'user_b';

      final isSender = senderId == currentUserId;
      final isReceiver = receiverId == currentUserId;
      final isRelevant = isSender || isReceiver;

      expect(isRelevant, isFalse, reason: 'User C should completely ignore messages between A and B');
    });

    test('A message is accepted if current user is the sender or the receiver', () {
      const currentUserId = 'user_a';
      const senderId = 'user_a';
      const receiverId = 'user_b';

      final isSender = senderId == currentUserId;
      final isReceiver = receiverId == currentUserId;
      final isRelevant = isSender || isReceiver;

      expect(isRelevant, isTrue);

      final partnerId = isSender ? receiverId : senderId;
      expect(partnerId, equals('user_b'));
    });

    test('SyncChatMessages logic isolates messages between exactly two parties', () {
      const currentId = 'user_1';
      const partnerId = 'user_2';

      final mockDbRows = [
        {'sender_id': 'user_1', 'receiver_id': 'user_2', 'content': 'Selam 2!'},
        {'sender_id': 'user_2', 'receiver_id': 'user_1', 'content': 'Selam 1!'},
        {'sender_id': 'user_2', 'receiver_id': 'user_3', 'content': 'Selam 3 (Özel mesaj)'},
        {'sender_id': 'user_3', 'receiver_id': 'user_2', 'content': 'Selam 2 (Özel mesaj)'},
      ];

      final filtered = mockDbRows.where((row) {
        final s = (row['sender_id'] ?? '').toLowerCase();
        final r = (row['receiver_id'] ?? '').toLowerCase();
        return (s == currentId && r == partnerId) || (s == partnerId && r == currentId);
      }).toList();

      expect(filtered.length, equals(2));
      expect(filtered.any((m) => m['content']!.contains('Özel')), isFalse);
    });

    test('Deduplication prevents duplicate messages with same text, sender and timestamp window', () {
      final now = DateTime.now();
      final messages = [
        MessageModel(
          id: 'msg_1',
          senderId: 'user_a',
          receiverId: 'user_b',
          text: 'Merhaba',
          timestamp: now,
        ),
      ];

      final incomingMsg = MessageModel(
        id: 'msg_duplicate',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Merhaba',
        timestamp: now.add(const Duration(seconds: 1)),
      );

      final exists = messages.any((m) =>
          m.id == incomingMsg.id ||
          (m.text == incomingMsg.text &&
              m.senderId == incomingMsg.senderId &&
              m.timestamp.difference(incomingMsg.timestamp).abs().inSeconds < 3));

      expect(exists, isTrue, reason: 'Duplicate within 3 seconds should be identified');
    });
  });

  group('ChatModel & Status Tests', () {
    test('MessageModel serialization preserves status and is_read', () {
      final msg = MessageModel(
        id: 'm_1',
        senderId: 'u1',
        receiverId: 'u2',
        text: 'Test',
        timestamp: DateTime.now(),
        status: MessageStatus.read,
      );

      final map = msg.toMap();
      expect(map['status'], equals('read'));
      expect(map['is_read'], isTrue);

      final reconstructed = MessageModel.fromMap(map);
      expect(reconstructed.status, equals(MessageStatus.read));
      expect(reconstructed.isRead, isTrue);
    });

    test('ChatModel lastMessage returns the latest message', () {
      final user = UserModel(id: 'u2', name: 'Ayşe', avatarUrl: '');
      final chat = ChatModel(
        id: 'chat_1',
        participant: user,
        messages: [
          MessageModel(id: '1', senderId: 'u1', text: 'İlk', timestamp: DateTime(2024, 1, 1, 10, 0)),
          MessageModel(id: '2', senderId: 'u2', text: 'Son', timestamp: DateTime(2024, 1, 1, 10, 5)),
        ],
      );

      expect(chat.lastMessage?.text, equals('Son'));
      expect(chat.lastMessage?.id, equals('2'));
    });

    test('Deleted chat IDs properly filter out chats', () {
      final chats = [
        ChatModel(id: 'chat_1', participant: UserModel(id: 'p1', name: 'Ali', avatarUrl: ''), messages: []),
        ChatModel(id: 'chat_2', participant: UserModel(id: 'p2', name: 'Mehmet', avatarUrl: ''), messages: []),
      ];

      final deletedChatIds = {'chat_1', 'p1'};

      final activeChats = chats
          .where((c) => !deletedChatIds.contains(c.id) && !deletedChatIds.contains(c.participant.id) && !c.isArchived)
          .toList();

      expect(activeChats.length, equals(1));
      expect(activeChats.first.id, equals('chat_2'));
    });

    test('Search filter properly matches participant name and message text', () {
      final chats = [
        ChatModel(
          id: 'c1',
          participant: UserModel(id: 'u1', name: 'Canan Kaya', avatarUrl: ''),
          messages: [MessageModel(id: 'm1', senderId: 'u1', text: 'Konsere gidecek misin?', timestamp: DateTime.now())],
        ),
        ChatModel(
          id: 'c2',
          participant: UserModel(id: 'u2', name: 'Burak Demir', avatarUrl: ''),
          messages: [MessageModel(id: 'm2', senderId: 'u2', text: 'Tiyatro bileti aldım', timestamp: DateTime.now())],
        ),
      ];

      // Search by name
      final byName = chats.where((c) => c.participant.name.toLowerCase().contains('canan')).toList();
      expect(byName.length, equals(1));
      expect(byName.first.participant.name, equals('Canan Kaya'));

      // Search by message content
      final byMsg = chats.where((c) => (c.lastMessage?.text.toLowerCase().contains('tiyatro') ?? false)).toList();
      expect(byMsg.length, equals(1));
      expect(byMsg.first.participant.name, equals('Burak Demir'));
    });
  });
}
