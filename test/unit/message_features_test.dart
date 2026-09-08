import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/messages/models/message_model.dart';

void main() {
  group('1. Canlı Yazıyor (Typing Indicator) & Durum Mantığı', () {
    test('Typing status payload is correctly parsed for sender and receiver', () {
      const currentUserId = 'user_me';
      const partnerId = 'user_partner';

      final typingPayload = {
        'sender_id': partnerId,
        'receiver_id': currentUserId,
        'is_typing': true,
      };

      final isForMe = typingPayload['receiver_id'] == currentUserId;
      final isFromPartner = typingPayload['sender_id'] == partnerId;
      final isTyping = typingPayload['is_typing'] == true;

      expect(isForMe, isTrue);
      expect(isFromPartner, isTrue);
      expect(isTyping, isTrue);
    });
  });

  group('2. Mesaj Reaksiyonları (Emoji Reactions) Testleri', () {
    test('Reactions are stored, counted and toggled accurately', () {
      final message = MessageModel(
        id: 'msg_101',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Bu akşam konsere gidiyoruz!',
        timestamp: DateTime.now(),
        reactions: {'user_b': '❤️'},
      );

      expect(message.reactions['user_b'], equals('❤️'));
      expect(message.reactionCounts['❤️'], equals(1));
      expect(message.myReaction('user_b'), equals('❤️'));
      expect(message.myReaction('user_a'), isNull);

      // Başka bir kullanıcı reaksiyon eklediğinde
      final updated = message.copyWith(reactions: {
        ...message.reactions,
        'user_c': '🔥',
        'user_d': '❤️',
      });

      expect(updated.reactionCounts['❤️'], equals(2));
      expect(updated.reactionCounts['🔥'], equals(1));

      // Aynı emojiyi tekrar seçtiğinde kaldırma (toggle)
      final toggled = Map<String, String>.from(updated.reactions);
      toggled.remove('user_b');
      final finalMsg = updated.copyWith(reactions: toggled);

      expect(finalMsg.reactionCounts['❤️'], equals(1));
      expect(finalMsg.myReaction('user_b'), isNull);
    });

    test('MessageModel toMap and fromMap preserve emoji reactions', () {
      final msg = MessageModel(
        id: 'msg_react',
        senderId: 'u1',
        text: 'Reaksiyon testi',
        timestamp: DateTime.now(),
        reactions: {'u1': '😂', 'u2': '👏'},
      );

      final map = msg.toMap();
      expect(map['reactions'], isNotNull);

      final reconstructed = MessageModel.fromMap(map);
      expect(reconstructed.reactions['u1'], equals('😂'));
      expect(reconstructed.reactions['u2'], equals('👏'));
      expect(reconstructed.reactionCounts['😂'], equals(1));
      expect(reconstructed.reactionCounts['👏'], equals(1));
    });
  });

  group('3. Mesaja Alıntı Yaparak Yanıtlama (Swipe-to-Reply) Testleri', () {
    test('Encoded reply quote content is parsed seamlessly by MessageModel', () {
      const rawContent = '[reply:Ayşe:Yarın saat kaçta buluşuyoruz?]\nSaat 19:00 gibi Kadıköydeyim.';

      final parsed = MessageModel.parseEncodedContent(rawContent);
      expect(parsed.replySender, equals('Ayşe'));
      expect(parsed.replyText, equals('Yarın saat kaçta buluşuyoruz?'));
      expect(parsed.cleanText, equals('Saat 19:00 gibi Kadıköydeyim.'));
      expect(parsed.messageType, equals('text'));

      final msg = MessageModel.fromMap({
        'id': 'msg_reply_1',
        'sender_id': 'user_b',
        'content': rawContent,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(msg.replyToSenderName, equals('Ayşe'));
      expect(msg.replyToText, equals('Yarın saat kaçta buluşuyoruz?'));
      expect(msg.text, equals('Saat 19:00 gibi Kadıköydeyim.'));
    });
  });

  group('4. Sesli Mesaj (Voice Note) Testleri', () {
    test('Audio message payload and tag encoding parse duration and mediaUrl', () {
      const rawAudioContent = '[audio:https://supabase.co/storage/v1/object/public/avatars/chat_audio/rec_123.m4a:14]';

      final parsed = MessageModel.parseEncodedContent(rawAudioContent);
      expect(parsed.messageType, equals('audio'));
      expect(parsed.audioDuration, equals(14));
      expect(parsed.mediaUrl, equals('https://supabase.co/storage/v1/object/public/avatars/chat_audio/rec_123.m4a'));
      expect(parsed.cleanText, equals('🎤 Sesli Mesaj'));

      final audioMsg = MessageModel.fromMap({
        'id': 'msg_voice_1',
        'sender_id': 'user_voice',
        'content': rawAudioContent,
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(audioMsg.isAudio, isTrue);
      expect(audioMsg.audioDurationSeconds, equals(14));
      expect(audioMsg.mediaUrl, contains('rec_123.m4a'));
    });
  });

  group('5. Tık Durumu (Single/Double/Blue Tick) Yaşam Döngüsü Testleri', () {
    test('Message statuses transition: sending -> sent -> delivered -> read', () {
      // 1. Kullanıcı gönderirken: Saat ikonu
      final sendingMsg = MessageModel(
        id: 'temp_1',
        senderId: 'user_me',
        text: 'Selam',
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );
      expect(sendingMsg.status, equals(MessageStatus.sending));

      // 2. Supabase DB kaydı tamamlandığında: Tek gri tık (sent)
      sendingMsg.status = MessageStatus.sent;
      expect(sendingMsg.status, equals(MessageStatus.sent));

      // 3. Karşı tarafa ulaştığında: Çift gri tık (delivered)
      sendingMsg.status = MessageStatus.delivered;
      expect(sendingMsg.status, equals(MessageStatus.delivered));

      // 4. Karşı taraf sohbeti açıp okuduğunda: Çift mavi tık (read)
      sendingMsg.status = MessageStatus.read;
      expect(sendingMsg.status, equals(MessageStatus.read));
      expect(sendingMsg.isRead, isTrue);
    });

    test('Supabase row with is_read == true MUST yield MessageStatus.read (Double Blue Tick)', () {
      final dbRowRead = {
        'id': 789,
        'sender_id': 'user_me',
        'receiver_id': 'user_partner',
        'content': 'Orada mısın?',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': true,
      };

      final msg = MessageModel.fromMap(dbRowRead);
      expect(msg.status, equals(MessageStatus.read), reason: 'DB is_read == true olunca çift mavi tık olmalı');
      expect(msg.isRead, isTrue);

      final dbRowUnread = {
        'id': 790,
        'sender_id': 'user_me',
        'receiver_id': 'user_partner',
        'content': 'Bekliyorum',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      final msgUnread = MessageModel.fromMap(dbRowUnread);
      expect(msgUnread.status, isNot(equals(MessageStatus.read)), reason: 'Okunmamış mesaj mavi tık olmamalı');
    });
  });
}
