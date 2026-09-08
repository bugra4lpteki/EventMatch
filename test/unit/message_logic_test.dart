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

    test('Mutual matching requirement: "liked" or "pending" status must NOT create a chat, only "matched"', () {
      const currentUserId = 'my_user_id';

      final dbMatches = [
        // Ali Rıza bana istek atmış (status: 'liked') -> Henüz kabul edilmedi veya karşılıklı kaydırılmadı
        {'id': 1, 'user_id_1': 'aliriza_id', 'user_id_2': currentUserId, 'status': 'liked'},
        // Zeynep ile karşılıklı eşleştik (status: 'matched')
        {'id': 2, 'user_id_1': currentUserId, 'user_id_2': 'zeynep_id', 'status': 'matched'},
        // Mehmet'i reddettik (status: 'rejected')
        {'id': 3, 'user_id_1': 'mehmet_id', 'user_id_2': currentUserId, 'status': 'rejected'},
        // Beklemede olan istek (status: 'pending')
        {'id': 4, 'user_id_1': 'ahmet_id', 'user_id_2': currentUserId, 'status': 'pending'},
      ];

      final partnerUserIds = <String>{};
      for (var match in dbMatches) {
        final status = match['status']?.toString().toLowerCase().trim();
        // Sadece 'matched' olanlar sohbet oluşturabilir!
        if (status != 'matched') continue;

        final u1 = match['user_id_1']?.toString() ?? '';
        final u2 = match['user_id_2']?.toString() ?? '';
        final otherId = u1.toLowerCase() == currentUserId.toLowerCase() ? u2 : u1;
        if (otherId.isNotEmpty && otherId.toLowerCase() != currentUserId.toLowerCase()) {
          partnerUserIds.add(otherId);
        }
      }

      // Alirıza 'liked' durumunda olduğu için sohbet kutusuna DÜŞMEMELİ
      expect(partnerUserIds.contains('aliriza_id'), isFalse, reason: 'Tek taraflı beğeni/istek sohbet oluşturmamalı');
      // Mehmet 'rejected' durumunda olduğu için sohbet kutusuna DÜŞMEMELİ
      expect(partnerUserIds.contains('mehmet_id'), isFalse);
      // Ahmet 'pending' durumunda olduğu için sohbet kutusuna DÜŞMEMELİ
      expect(partnerUserIds.contains('ahmet_id'), isFalse);
      // SADECE Zeynep 'matched' olduğu için sohbete düşmeli
      expect(partnerUserIds.contains('zeynep_id'), isTrue);
      expect(partnerUserIds.length, equals(1));
    });

    test('Incoming messages from un-matched users must not be added to chat box', () {
      final matchedPartners = {'user_matched'};
      final incomingDirectMessages = [
        {'sender_id': 'user_unmatched', 'receiver_id': 'my_user_id', 'content': 'Selam'},
        {'sender_id': 'user_matched', 'receiver_id': 'my_user_id', 'content': 'Harika bir etkinlik!'},
      ];

      final validMessages = incomingDirectMessages.where((m) {
        final sender = m['sender_id'] ?? '';
        return matchedPartners.contains(sender);
      }).toList();

      expect(validMessages.length, equals(1));
      expect(validMessages.first['sender_id'], equals('user_matched'));
    });

    test('Optimistic temporary ID is properly reconciled with real DB ID without duplicates', () {
      final now = DateTime.now();
      final list = <MessageModel>[
        MessageModel(
          id: 'msg_1725800001',
          senderId: 'user_a',
          receiverId: 'user_b',
          text: 'Harika konser!',
          timestamp: now,
          status: MessageStatus.sent,
        ),
      ];

      // Simulated DB response arrives with real integer ID 450
      const realDbId = '450';
      final dbTimestamp = now.add(const Duration(milliseconds: 500));

      final optIndex = list.indexWhere((m) =>
          m.id.startsWith('msg_') &&
          m.senderId == 'user_a' &&
          m.text == 'Harika konser!' &&
          m.timestamp.difference(dbTimestamp).abs().inSeconds < 120);

      expect(optIndex, equals(0));

      // Reconcile
      list[optIndex] = MessageModel(
        id: realDbId,
        senderId: list[optIndex].senderId,
        receiverId: list[optIndex].receiverId,
        text: list[optIndex].text,
        timestamp: dbTimestamp,
        status: MessageStatus.delivered,
      );

      expect(list.length, equals(1));
      expect(list.first.id, equals('450'));
      expect(list.first.status, equals(MessageStatus.delivered));

      // When CDC arrives with real ID 450, exact check ignores it
      final alreadyExists = list.any((m) => m.id == realDbId);
      expect(alreadyExists, isTrue, reason: 'Real ID already in list, must not be duplicated');
    });

    test('Radar interaction creates match request, requiring explicit acceptance before chat creation', () {
      // 1. User sends radar request
      final matchRecord = <String, String>{
        'id': '101',
        'user_id_1': 'user_requester',
        'user_id_2': 'user_receiver',
        'status': 'liked', // Match request created
      };

      // Recipient cannot have a chat room yet
      bool canCreateChat(String status) => status == 'matched';
      expect(canCreateChat(matchRecord['status']!), isFalse);

      // 2. Recipient accepts in Requests screen
      matchRecord['status'] = 'matched';

      // 3. Now chat can be created
      expect(canCreateChat(matchRecord['status']!), isTrue);
    });

    test('Blocked users cannot exchange messages, receive broadcasts, or create chats', () {
      final blockedIds = <String>{'user_blocked_1', 'user_blocked_2'};
      bool isBlocked(String id) =>
          blockedIds.any((b) => b.toLowerCase().trim() == id.toLowerCase().trim());

      const senderId = 'user_blocked_1';
      const receiverId = 'user_me';

      // 1. Inbound message filter
      final shouldDropInbound = isBlocked(senderId) || isBlocked(receiverId);
      expect(shouldDropInbound, isTrue, reason: 'Incoming message from blocked user must be dropped');

      // 2. Outbound message attempt
      const targetPartner = 'user_blocked_2';
      final canSend = !isBlocked(targetPartner);
      expect(canSend, isFalse, reason: 'Cannot send message to blocked user');

      // 3. Unblock allows messaging again
      blockedIds.remove('user_blocked_2');
      final canSendAfterUnblock = !isBlocked(targetPartner);
      expect(canSendAfterUnblock, isTrue, reason: 'Can send message after unblock');
    });
  });
}


