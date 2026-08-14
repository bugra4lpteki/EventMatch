import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/events/models/event_model.dart';
import 'package:event_match/features/events/models/user_model.dart';

void main() {
  group('EventModel Tests', () {
    test('Image URL sanitization handles empty or broken URLs with defaults', () {
      final event = EventModel(
        id: '1',
        title: 'Müzik Festivali',
        category: 'Müzik',
        location: 'İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        description: 'Açıklama',
        imageUrl: '',
      );

      expect(event.imageUrl, isNotEmpty);
      expect(event.imageUrl.startsWith('http'), isTrue);
    });

    test('fromMap creates valid EventModel with attendees and fallback defaults', () {
      final mapData = {
        'id': 'test_123',
        'title': 'Teknoloji Zirvesi',
        'type': 'Teknoloji',
        'venue': 'Kolektif House',
        'city': 'İstanbul',
        'date': DateTime.now().toIso8601String(),
        'description': 'AI sohbetleri',
        'image_url': 'https://example.com/image.jpg',
        'lat': 41.04,
        'lng': 28.99,
        'tag': 'Popüler',
      };

      final event = EventModel.fromMap(mapData);

      expect(event.id, equals('test_123'));
      expect(event.title, equals('Teknoloji Zirvesi'));
      expect(event.category, equals('Teknoloji'));
      expect(event.latitude, equals(41.04));
      expect(event.longitude, equals(28.99));
      expect(event.attendees, isEmpty);
    });

    test('fromMap handles null or missing fields gracefully without crash', () {
      final mapData = <String, dynamic>{
        'id': null,
        'title': null,
      };

      final event = EventModel.fromMap(mapData);

      expect(event.id, isNotEmpty);
      expect(event.title, equals('İsimsiz Etkinlik'));
      expect(event.category, equals('Genel'));
      expect(event.location, equals('Bilinmiyor'));
    });
  });
}
