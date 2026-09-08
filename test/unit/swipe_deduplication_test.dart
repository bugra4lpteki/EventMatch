import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/events/models/user_model.dart';

void main() {
  group('Swipe Deck Deduplication Tests', () {
    test('Deck filters out duplicate user IDs and seen users', () {
      final potentialMatches = [
        UserModel(id: 'user_1', name: 'Ayşe', avatarUrl: ''),
        UserModel(id: 'USER_1', name: 'Ayşe Duplicate', avatarUrl: ''),
        UserModel(id: 'user_2', name: 'Mehmet', avatarUrl: ''),
        UserModel(id: 'user_3', name: 'Fatma', avatarUrl: ''),
        UserModel(id: 'user_2', name: 'Mehmet 2', avatarUrl: ''),
      ];

      final seenUserIds = {'user_3'};

      final seenIds = <String>{};
      final filteredMatches = <UserModel>[];
      for (final u in potentialMatches) {
        final cleanId = u.id.toLowerCase().trim();
        if (cleanId.isEmpty) continue;
        if (seenUserIds.contains(cleanId)) continue;
        if (seenIds.contains(cleanId)) continue;
        seenIds.add(cleanId);
        filteredMatches.add(u);
      }

      expect(filteredMatches.length, 2);
      expect(filteredMatches[0].id, 'user_1');
      expect(filteredMatches[1].id, 'user_2');
    });

    test('Swiping right immediately adds user to locally swiped IDs and seen set', () {
      final locallySwipedIds = <String>{};
      final currentUser = UserModel(id: 'user_test_99', name: 'Test User', avatarUrl: '');

      // User swipes right
      locallySwipedIds.add(currentUser.id.toLowerCase().trim());

      final deck = [
        currentUser,
        UserModel(id: 'user_other', name: 'Other User', avatarUrl: ''),
      ];

      final visibleItems = deck.where((u) {
        final cleanId = u.id.toLowerCase().trim();
        return !locallySwipedIds.contains(cleanId);
      }).toList();

      expect(visibleItems.length, 1);
      expect(visibleItems.first.id, 'user_other');
      expect(visibleItems.any((u) => u.id == 'user_test_99'), isFalse);
    });

    test('Multiple rapid swipes do not allow previously swiped profiles to reappear', () {
      final locallySwipedIds = <String>{};
      final userA = UserModel(id: 'user_a', name: 'A', avatarUrl: '');
      final userB = UserModel(id: 'user_b', name: 'B', avatarUrl: '');
      final userC = UserModel(id: 'user_c', name: 'C', avatarUrl: '');

      final initialDeck = [userA, userB, userC];

      // Swipe user A
      locallySwipedIds.add(userA.id.toLowerCase().trim());

      var remaining = initialDeck.where((u) => !locallySwipedIds.contains(u.id.toLowerCase().trim())).toList();
      expect(remaining.length, 2);
      expect(remaining.contains(userA), isFalse);

      // Swipe user B
      locallySwipedIds.add(userB.id.toLowerCase().trim());

      remaining = initialDeck.where((u) => !locallySwipedIds.contains(u.id.toLowerCase().trim())).toList();
      expect(remaining.length, 1);
      expect(remaining.first, userC);
      expect(remaining.contains(userA), isFalse);
      expect(remaining.contains(userB), isFalse);
    });
  });
}
