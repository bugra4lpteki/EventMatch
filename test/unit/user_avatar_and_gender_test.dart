import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/events/models/user_model.dart';

void main() {
  group('UserModel Gender and Photo Validation Tests', () {
    test('isValidPhotoUrl rejects placeholder, stock and AI unsplash URLs', () {
      expect(UserModel.isValidPhotoUrl(null), false);
      expect(UserModel.isValidPhotoUrl(''), false);
      expect(UserModel.isValidPhotoUrl('   '), false);
      expect(UserModel.isValidPhotoUrl('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600'), false);
      expect(UserModel.isValidPhotoUrl('assets/images/user_avatar.jpg'), false);
      expect(UserModel.isValidPhotoUrl('https://i.pravatar.cc/300'), false);
      expect(UserModel.isValidPhotoUrl('https://randomuser.me/api/portraits/men/1.jpg'), false);
      expect(UserModel.isValidPhotoUrl('invalid-url-string'), false);

      // Real user uploads to Supabase storage must be accepted
      expect(UserModel.isValidPhotoUrl('https://myproject.supabase.co/storage/v1/object/public/user_photos/user1_123.jpg'), true);
      expect(UserModel.isValidPhotoUrl('https://cdn.example.com/uploads/photo.png'), true);
    });

    test('isMale and isFemale correctly identify gender values', () {
      final male1 = UserModel(id: '1', name: 'Ali', avatarUrl: '', gender: 'Erkek');
      final male2 = UserModel(id: '2', name: 'John', avatarUrl: '', gender: 'male');
      final female1 = UserModel(id: '3', name: 'Ayşe', avatarUrl: '', gender: 'Kadın');
      final female2 = UserModel(id: '4', name: 'Jane', avatarUrl: '', gender: 'female');
      final unspec = UserModel(id: '5', name: 'Alex', avatarUrl: '', gender: 'Belirtmek İstemiyorum');
      final nullGender = UserModel(id: '6', name: 'Sam', avatarUrl: '');

      expect(male1.isMale, true);
      expect(male1.isFemale, false);

      expect(male2.isMale, true);
      expect(male2.isFemale, false);

      expect(female1.isFemale, true);
      expect(female1.isMale, false);

      expect(female2.isFemale, true);
      expect(female2.isMale, false);

      expect(unspec.isMale, false);
      expect(unspec.isFemale, false);

      expect(nullGender.isMale, false);
      expect(nullGender.isFemale, false);
    });

    test('UserModel.fromMap strips fake Unsplash and placeholder URLs', () {
      final mapWithUnsplash = {
        'id': 'user_123',
        'name': 'Eren Denizhan',
        'username': 'erendenizhan',
        'avatarUrl': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600',
        'avatarUrls': ['https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600'],
        'gender': 'Erkek',
      };

      final user = UserModel.fromMap(mapWithUnsplash);
      expect(user.avatarUrl, '');
      expect(user.avatarUrls, isEmpty);
      expect(user.hasRealPhoto, false);
      expect(user.isMale, true);
    });

    test('UserModel.fromMap preserves real uploaded photo URLs', () {
      final realUrl = 'https://myproject.supabase.co/storage/v1/object/public/user_photos/u1_real.jpg';
      final mapWithReal = {
        'id': 'user_456',
        'name': 'Zeynep Kaya',
        'avatarUrl': realUrl,
        'avatarUrls': [realUrl],
        'gender': 'Kadın',
      };

      final user = UserModel.fromMap(mapWithReal);
      expect(user.avatarUrl, realUrl);
      expect(user.avatarUrls, [realUrl]);
      expect(user.hasRealPhoto, true);
      expect(user.isFemale, true);
    });
  });
}
