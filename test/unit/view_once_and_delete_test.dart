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

    test('Uncaptioned view-once message parses cleanText as Tek seferlik fotoğraf', () {
      const rawUncaptioned = '[view_once:https://example.com/photos/secret.jpg]';
      final parsed = MessageModel.parseEncodedContent(rawUncaptioned);

      expect(parsed.isViewOnce, isTrue);
      expect(parsed.isViewOnceOpened, isFalse);
      expect(parsed.cleanText, equals('Tek seferlik fotoğraf'));
      expect(parsed.mediaUrl, equals('https://example.com/photos/secret.jpg'));
    });

    test('previewText formats view-once messages properly for chat list and notifications', () {
      final uncaptionedMsg = MessageModel(
        id: 'vo_uncaptioned',
        senderId: 'u1',
        text: 'Tek seferlik fotoğraf',
        timestamp: DateTime.now(),
        messageType: 'view_once',
        isViewOnce: true,
        isViewOnceOpened: false,
      );
      expect(uncaptionedMsg.previewText, equals('📷 Tek seferlik fotoğraf'));

      final captionedMsg = MessageModel(
        id: 'vo_captioned',
        senderId: 'u1',
        text: 'Özel parti fotoğrafı',
        timestamp: DateTime.now(),
        messageType: 'view_once',
        isViewOnce: true,
        isViewOnceOpened: false,
      );
      expect(captionedMsg.previewText, equals('📷 Tek seferlik fotoğraf: Özel parti fotoğrafı'));

      final openedMsg = uncaptionedMsg.copyWith(isViewOnceOpened: true, text: 'Açıldı');
      expect(openedMsg.previewText, equals('📷 Tek seferlik fotoğraf (Açıldı)'));
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

  group('2. Mesaj Silme (Benden Sil & Herkes İçin Sil) ve "Bu mesaj silindi" Testleri', () {
    test('Raw [deleted] content parses to isDeleted: true and cleanText: Bu mesaj silindi', () {
      final parsed = MessageModel.parseEncodedContent('[deleted]');
      expect(parsed.isDeleted, isTrue);
      expect(parsed.cleanText, equals('Bu mesaj silindi'));
      expect(parsed.mediaUrl, isNull);
    });

    test('Raw "Bu mesajı sildiniz" preserves self-deleted message text', () {
      final parsed = MessageModel.parseEncodedContent('Bu mesajı sildiniz');
      expect(parsed.isDeleted, isTrue);
      expect(parsed.cleanText, equals('Bu mesajı sildiniz'));
    });

    test('Deleted message suppresses isAudio and isImage flags', () {
      final deletedVoice = MessageModel(
        id: 'del_voice_1',
        senderId: 'u1',
        text: 'Bu mesaj silindi',
        timestamp: DateTime.now(),
        messageType: 'audio',
        mediaUrl: 'https://example.com/audio.m4a',
        isDeleted: true,
      );

      expect(deletedVoice.isAudio, isFalse);
      expect(deletedVoice.isImage, isFalse);
      expect(deletedVoice.isDeleted, isTrue);
      expect(deletedVoice.text, equals('Bu mesaj silindi'));

      final deletedImage = MessageModel(
        id: 'del_img_1',
        senderId: 'u1',
        text: 'Bu mesajı sildiniz',
        timestamp: DateTime.now(),
        messageType: 'image',
        mediaUrl: 'https://example.com/photo.jpg',
        isDeleted: true,
      );

      expect(deletedImage.isImage, isFalse);
      expect(deletedImage.isAudio, isFalse);
      expect(deletedImage.isDeleted, isTrue);
      expect(deletedImage.text, equals('Bu mesajı sildiniz'));
    });

    test('Soft delete retains message in chat list with "Bu mesaj silindi" status', () {
      final localMessages = [
        MessageModel(id: 'msg_1', senderId: 'u1', text: 'Merhaba', timestamp: DateTime.now()),
        MessageModel(id: 'msg_2', senderId: 'u1', text: 'Önemli bilgi', timestamp: DateTime.now()),
      ];

      // Mesajı tamamen silmek yerine 'Bu mesaj silindi' olarak güncelle
      final idx = localMessages.indexWhere((m) => m.id == 'msg_2');
      expect(idx, equals(1));
      localMessages[idx] = localMessages[idx].copyWith(
        isDeleted: true,
        text: 'Bu mesaj silindi',
        mediaUrl: null,
      );

      expect(localMessages.length, equals(2));
      expect(localMessages[1].isDeleted, isTrue);
      expect(localMessages[1].text, equals('Bu mesaj silindi'));
    });

    test('fromMap parses is_deleted flag and [deleted] content correctly', () {
      final msgFromDb = MessageModel.fromMap({
        'id': 'm_db_1',
        'sender_id': 'u1',
        'content': '[deleted]',
        'is_read': true,
      });

      expect(msgFromDb.isDeleted, isTrue);
      expect(msgFromDb.text, equals('Bu mesaj silindi'));
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
