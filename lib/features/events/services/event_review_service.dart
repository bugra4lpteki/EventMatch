import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_review_model.dart';

class EventReviewService extends ChangeNotifier {
  static final EventReviewService _instance = EventReviewService._internal();
  factory EventReviewService() => _instance;
  EventReviewService._internal() {
    _initSeedReviews();
  }

  final Map<String, List<EventReviewModel>> _reviewsCache = {};

  void _initSeedReviews() {
    // Realistic initial reviews for sample events
    _reviewsCache['1'] = [
      EventReviewModel(
        id: 'rev_1',
        eventId: '1',
        userId: 'u_101',
        userName: 'Zeynep Kaya',
        userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        rating: 5,
        comment: 'Harika bir konser ortamı vardı! Ses sistemi ve ışıklar tek kelimeyle kusursuzdu.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      EventReviewModel(
        id: 'rev_2',
        eventId: '1',
        userId: 'u_102',
        userName: 'Burak Demir',
        userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        rating: 5,
        comment: 'EventMatch sayesinde konser arkadaşı bulup birlikte gittik, inanılmaz eğlendik.',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      EventReviewModel(
        id: 'rev_3',
        eventId: '1',
        userId: 'u_103',
        userName: 'Melis Arslan',
        userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        rating: 4,
        comment: 'Giriş kapısında biraz sıra vardı ama içerideki atmosfer her şeye değdi!',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
    ];

    _reviewsCache['2'] = [
      EventReviewModel(
        id: 'rev_4',
        eventId: '2',
        userId: 'u_104',
        userName: 'Canberk Yıldız',
        userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        rating: 5,
        comment: 'Açık hava sineması konsepti muhteşemdi, patlamış mısır ikramı çok tatlı bir detaydı.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<EventReviewModel> getCachedReviews(String eventId) {
    return _reviewsCache[eventId] ?? [];
  }

  double getAverageRating(String eventId) {
    final list = _reviewsCache[eventId];
    if (list == null || list.isEmpty) return 4.9; // Default high rating for new events
    final sum = list.fold<int>(0, (prev, r) => prev + r.rating);
    return double.parse((sum / list.length).toStringAsFixed(1));
  }

  int getReviewCount(String eventId) {
    final list = _reviewsCache[eventId];
    return list?.length ?? 0;
  }

  Future<List<EventReviewModel>> fetchReviews(String eventId) async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('event_reviews')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      final fetched = (res as List)
          .map((item) => EventReviewModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (fetched.isNotEmpty) {
        _reviewsCache[eventId] = fetched;
        notifyListeners();
        return fetched;
      }
    } catch (e) {
      debugPrint('[EventReviewService] Supabase fetch fallback: $e');
    }
    return _reviewsCache[eventId] ?? [];
  }

  Future<bool> addReview({
    required String eventId,
    required String userId,
    required String userName,
    String? userAvatar,
    required int rating,
    required String comment,
  }) async {
    final newReview = EventReviewModel(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );

    // Save to local cache first
    _reviewsCache.putIfAbsent(eventId, () => []);
    _reviewsCache[eventId]!.insert(0, newReview);
    notifyListeners();

    // Persist to Supabase if connected
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('event_reviews').insert({
        'event_id': eventId,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[EventReviewService] Supabase insert fallback: $e');
    }

    return true;
  }
}
