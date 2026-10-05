import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/messages/models/message_model.dart';
import 'package:event_match/core/services/security_screen_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Tek Oynatımlık Fotoğraf (View-Once Photo) Testleri', () {
    test('View-once message encoding and parsing works correctly', () {
      const rawViewOnce = '[view_once:https://example.com/photos/secret.jpg]\nÖzel anımız';
      final parsed = MessageModel.parseEncodedContent(rawViewOnce);

      expect(parsed.isViewOnce, isTrue);
      expect(parsed.isViewOnceOpened, isFalse);
      expect(parsed.mediaUrl, equals('https://example.com/photos/secret.jpg'));
      expect(parsed.cleanText, equals('Özel anımız'));
      expect(parsed.messageType, equals('view_once'));
    });

    test('Opened view-once message parses correctly with opened status', () {
      const rawOpened = '[view_once:https://example.com/photos/secret.jpg|||opened]';
      final parsed = MessageModel.parseEncodedContent(rawOpened);

      expect(parsed.isViewOnce, isTrue);
      expect(parsed.isViewOnceOpened, isTrue);
      expect(parsed.mediaUrl, equals('https://example.com/photos/secret.jpg'));
      expect(parsed.cleanText, equals('Açıldı'));
      expect(parsed.messageType, equals('view_once'));
    });

    test('MessageModel does not classify view-once as regular auto-rendered image', () {
      final msg = MessageModel(
        id: 'vo_1',
        senderId: 'u1',
        text: 'Gizli Foto',
        timestamp: DateTime.now(),
        mediaUrl: 'https://example.com/secret.jpg',
        messageType: 'view_once',
        isViewOnce: true,
        isViewOnceOpened: false,
      );

      // isImage false olmalıdır ki doğrudan ekranda fotoğraf açılmasın, (1) kapsül butonu görünsün
      expect(msg.isImage, isFalse);
      expect(msg.isViewOnce, isTrue);
      expect(msg.isViewOnceOpened, isFalse);

      // Açıldıktan sonra
      final openedMsg = msg.copyWith(isViewOnceOpened: true, text: 'Açıldı');
      expect(openedMsg.isViewOnce, isTrue);
      expect(openedMsg.isViewOnceOpened, isTrue);
      expect(openedMsg.text, equals('Açıldı'));
    });

    test('MessageModel toMap and fromMap preserve view_once attributes', () {
      final original = MessageModel(
        id: 'vo_map',
        senderId: 'user_sender',
        receiverId: 'user_receiver',
        text: 'Tek seferlik',
        timestamp: DateTime.now(),
        mediaUrl: 'https://example.com/photo.png',
        messageType: 'view_once',
        isViewOnce: true,
        isViewOnceOpened: false,
      );

      final map = original.toMap();
      expect(map['is_view_once'], isTrue);
      expect(map['is_view_once_opened'], isFalse);

      final restored = MessageModel.fromMap(map);
      expect(restored.isViewOnce, isTrue);
      expect(restored.isViewOnceOpened, isFalse);
      expect(restored.messageType, equals('view_once'));
    });
  });

  group('2. Mesaj Silme (Benden Sil & Herkes İçin Sil) Mantık Testleri', () {
    test('Benden Sil: Gizlenen mesaj kimliği diğer kullanıcıların listesini etkilemeden filtrelenir', () {
      final hiddenSet = <String>{};
      const msgToDeleteForMe = 'msg_for_me_123';

      hiddenSet.add(msgToDeleteForMe.toLowerCase());

      final incomingMessages = [
        {'id': 'msg_for_me_123', 'content': 'Gizli mesaj'},
        {'id': 'msg_keep_456', 'content': 'Kalan mesaj'},
      ];

      final filtered = incomingMessages.where((m) => !hiddenSet.contains(m['id']!.toLowerCase())).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first['id'], equals('msg_keep_456'));
    });

    test('Herkes İçin Sil: Silinen mesaj kimliği broadcast ve senkronizasyonda elenir', () {
      final deletedForEveryone = <String>{};
      const broadcastDeletedId = 'msg_everyone_999';

      deletedForEveryone.add(broadcastDeletedId.toLowerCase());

      final localMessages = [
        MessageModel(id: 'msg_everyone_999', senderId: 'u1', text: 'Silinecek', timestamp: DateTime.now()),
        MessageModel(id: 'msg_valid_111', senderId: 'u1', text: 'Normal', timestamp: DateTime.now()),
      ];

      localMessages.removeWhere((m) => deletedForEveryone.contains(m.id.toLowerCase()));

      expect(localMessages.length, equals(1));
      expect(localMessages.first.id, equals('msg_valid_111'));
    });
  });

  group('3. Ekran Görüntüsü ve Kayıt Güvenliği (Anti-Screenshot) Testleri', () {
    test('SecurityScreenService singleton instance exists and manages secure state', () async {
      final service = SecurityScreenService.instance;
      expect(service, isNotNull);
      expect(service.isSecure, isFalse);

      await service.enableSecure();
      expect(service.isSecure, isTrue);

      await service.disableSecure();
      expect(service.isSecure, isFalse);
    });
  });
}
