import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/events/models/event_model.dart';

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
      expect(event.location, equals('Kolektif House, İstanbul'));
    });

    test('24-hour room window rule: activates 24 hours prior to event start time', () {
      final now = DateTime.now();

      // Event in 3 days -> NOT active, has positive time remaining
      final futureEvent = EventModel(
        id: 'future_1',
        title: 'Gelecek Konser',
        category: 'Konser',
        location: 'Harbiye',
        dateTime: now.add(const Duration(days: 3)),
        description: 'Test',
        imageUrl: 'https://example.com/img.jpg',
      );
      expect(futureEvent.isRoomActive, isFalse);
      expect(futureEvent.isCheckInAvailable, isFalse);
      expect(futureEvent.timeUntilRoomOpens.inHours, greaterThan(24));

      // Event in 10 hours -> ACTIVE, within 24h window
      final activeEvent = EventModel(
        id: 'active_1',
        title: 'Bugün Konser',
        category: 'Konser',
        location: 'Dorock XL',
        dateTime: now.add(const Duration(hours: 10)),
        description: 'Test',
        imageUrl: 'https://example.com/img.jpg',
      );
      expect(activeEvent.isRoomActive, isTrue);
      expect(activeEvent.isCheckInAvailable, isTrue);
      expect(activeEvent.timeUntilRoomOpens, equals(Duration.zero));

      // Event happened 5 hours ago -> Still accessible (within 12h post-event)
      final ongoingEvent = EventModel(
        id: 'ongoing_1',
        title: 'Süren Konser',
        category: 'Konser',
        location: 'KüçükÇiftlik',
        dateTime: now.subtract(const Duration(hours: 5)),
        description: 'Test',
        imageUrl: 'https://example.com/img.jpg',
      );
      expect(ongoingEvent.isRoomActive, isTrue);
    });
  });
}
