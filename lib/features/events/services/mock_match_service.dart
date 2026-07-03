import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_request.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import 'mock_event_service.dart';

class MockMatchService extends ChangeNotifier {
  final MockEventService eventService;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String get currentUserId => _supabase.auth.currentUser?.id ?? 'user_1';

  List<UserModel> _potentialMatches = [];
  bool _isDoubleDateMode = false;
  bool get isDoubleDateMode => _isDoubleDateMode;

  MockMatchService(this.eventService) {
    loadPotentialMatches();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        loadPotentialMatches();
      } else {
        _potentialMatches.clear();
        notifyListeners();
      }
    });
  }

  // --- SUPABASE INTEGRATION ---

  Future<void> loadPotentialMatches() async {
    try {
      if (_supabase.auth.currentUser == null) {
        debugPrint('[MatchService] ❌ currentUser null, çıkılıyor');
        return;
      }
      debugPrint('[MatchService] ✅ currentUser: $currentUserId');

      // 1. Kullanıcının katıldığı etkinliğin event_id'sini al
      final myEventsRes = await _supabase.from('event_attendees')
          .select('event_id')
          .eq('user_id', currentUserId)
          .eq('status', 'joined');
      
      debugPrint('[MatchService] Adım 1 - Katıldığım etkinlikler: ${myEventsRes.length} adet');
      
      if (myEventsRes.isEmpty) {
        debugPrint('[MatchService] ❌ Katıldığım etkinlik yok, çıkılıyor');
        _potentialMatches.clear();
        notifyListeners();
        return;
      }
      final myEventIds = myEventsRes.map((e) => e['event_id']).toList();
      debugPrint('[MatchService] Event IDs: $myEventIds');

      // 2. event_attendees tablosundan o etkinlikteki tüm user_id'leri çek, kendininkini çıkar
      final otherAttendeesRes = await _supabase.from('event_attendees')
          .select('user_id')
          .inFilter('event_id', myEventIds)
          .neq('user_id', currentUserId)
          .eq('status', 'joined');

      debugPrint('[MatchService] Adım 2 - Diğer katılımcılar: ${otherAttendeesRes.length} adet');

      final potentialUserIds = otherAttendeesRes
          .map((row) => row['user_id'].toString())
          .toSet();
      
      debugPrint('[MatchService] Potansiyel user IDs: $potentialUserIds');

      // 3. matches tablosundan senin bu etkinlikte daha önce liked, rejected veya matched yaptıklarını çek
      final interactionsRes = await _supabase.from('matches')
          .select('user_id_1, user_id_2')
          .inFilter('event_id', myEventIds)
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId');
      
      debugPrint('[MatchService] Adım 3 - Önceki etkileşimler: ${interactionsRes.length} adet');

      final interactedUserIds = <String>{};
      for (var row in interactionsRes) {
        interactedUserIds.add(row['user_id_1']);
        interactedUserIds.add(row['user_id_2']);
      }

      final filteredUserIds = potentialUserIds
          .where((id) => !interactedUserIds.contains(id))
          .toList();

      debugPrint('[MatchService] Adım 3 - Filtrelenmiş user IDs (etkileşim çıkarıldı): $filteredUserIds');

      _potentialMatches.clear();
      
      if (filteredUserIds.isNotEmpty) {
        // 4. Kalan user_id'lerle user_profiles view'ından profil bilgilerini al
        List<Map<String, dynamic>> profilesRes = [];
        String idColumn = 'id'; // varsayılan
        
        try {
          // Önce view'ın kolon yapısını tespit et
          final sampleRow = await _supabase.from('user_profiles')
              .select()
              .limit(1);
          
          if (sampleRow.isNotEmpty) {
            final columns = sampleRow.first.keys.toList();
            debugPrint('[MatchService] user_profiles kolonları: $columns');
            
            // ID kolonu hangisi?
            if (!columns.contains('id') && columns.contains('user_id')) {
              idColumn = 'user_id';
            }
            debugPrint('[MatchService] Kullanılan ID kolonu: $idColumn');
            
            profilesRes = await _supabase.from('user_profiles')
                .select()
                .inFilter(idColumn, filteredUserIds);
            debugPrint('[MatchService] Adım 4 - user_profiles: ${profilesRes.length} profil bulundu');
          } else {
            debugPrint('[MatchService] ⚠️ user_profiles view boş');
          }
        } catch (e) {
          debugPrint('[MatchService] ❌ user_profiles hatası: $e');
        }

        // 5. Fotoğrafları çek
        List<Map<String, dynamic>> photosRes = [];
        try {
          photosRes = await _supabase.from('user_photos')
              .select('user_id, storage_url')
              .inFilter('user_id', filteredUserIds)
              .eq('is_active', true)
              .order('sort_order', ascending: true);
          debugPrint('[MatchService] Adım 5 - Fotoğraflar: ${photosRes.length} adet');
        } catch (e) {
          debugPrint('[MatchService] ⚠️ user_photos hatası: $e');
        }

        // Fotoğrafları kullanıcı id'sine göre grupla
        final Map<String, List<String>> userPhotosMap = {};
        for (var photo in photosRes) {
          final uId = photo['user_id'] as String;
          final url = photo['storage_url'] as String;
          userPhotosMap.putIfAbsent(uId, () => []).add(url);
        }

        for (var row in profilesRes) {
          final id = row[idColumn]; // Doğru kolon adını kullan
          final name = row['name'] ?? 'Kullanıcı $id';
          final username = row['username'];
          final bio = row['bio'] ?? row['about_me'] ?? '';
          final city = row['city'] ?? '';
          final gender = row['gender'] ?? '';
          
          DateTime? birthDate;
          if (row['birth_date'] != null) {
            birthDate = DateTime.tryParse(row['birth_date']);
          }
          
          final List<String> avatarUrls = userPhotosMap[id] ?? [];
          
          final String avatarUrl = avatarUrls.isNotEmpty 
              ? avatarUrls.first 
              : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100';
          
          List<String> tags = [];
          if (row['interests'] != null) {
            if (row['interests'] is List) {
              tags = List<String>.from(row['interests'] as List);
            } else if (row['interests'] is String) {
              final str = row['interests'] as String;
              if (str.trim().isNotEmpty) {
                tags = str.split(',').map((s) => s.trim()).toList();
              }
            }
          }

          _potentialMatches.add(UserModel(
            id: id,
            name: name,
            username: username,
            avatarUrl: avatarUrl,
            avatarUrls: avatarUrls,
            aboutMe: bio,
            city: city,
            gender: gender,
            birthDate: birthDate,
            tags: tags,
          ));
        }

        // Shuffle to get a random order (Rastgele sırayla gelsin)
        _potentialMatches.shuffle();
      }
      
      debugPrint('[MatchService] ✅ Toplam potansiyel eşleşme: ${_potentialMatches.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Load Potential Matches Error: $e');
    }
  }

  Future<void> swipeRight(UserModel targetUser) async {
    try {
      // Find a shared event id first
      final sharedEvents = await _supabase.from('event_attendees')
          .select('event_id')
          .eq('user_id', targetUser.id)
          .eq('status', 'joined');
      
      String eventId = sharedEvents.isNotEmpty ? sharedEvents.first['event_id'] : 'unknown_event';

      // Always insert a liked row, Supabase trigger handles matched logic
      await _supabase.from('matches').insert({
        'user_id_1': currentUserId,
        'user_id_2': targetUser.id,
        'event_id': eventId,
        'status': 'liked'
      });

      _potentialMatches.removeWhere((u) => u.id == targetUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Right Error: $e');
    }
  }

  Future<void> swipeLeft(UserModel targetUser) async {
    try {
      // Find a shared event id first
      final sharedEvents = await _supabase.from('event_attendees')
          .select('event_id')
          .eq('user_id', targetUser.id)
          .eq('status', 'joined');
      
      String eventId = sharedEvents.isNotEmpty ? sharedEvents.first['event_id'] : 'unknown_event';

      await _supabase.from('matches').insert({
          'user_id_1': currentUserId,
          'user_id_2': targetUser.id,
          'event_id': eventId,
          'status': 'rejected'
      });
      _potentialMatches.removeWhere((u) => u.id == targetUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Left Error: $e');
    }
  }

  List<UserModel> getPotentialMatches() => _potentialMatches;

  void toggleDoubleDateMode() {
    _isDoubleDateMode = !_isDoubleDateMode;
    notifyListeners();
  }

  List<GroupModel> getPotentialGroups() => []; // MOCK

  // Placeholder for incoming requests if needed for UI
  List<MatchRequest> get incomingRequests => [];

  // --- COMPATIBILITY METHODS FOR UI ---

  void sendRequest(String eventId, UserModel toUser) {
    swipeRight(toUser);
  }

  void acceptRequest(String requestId) {
    // Implement via Supabase matches update if needed
  }

  void rejectRequest(String requestId) {
    // Implement via Supabase matches update if needed
  }

  bool hasSentRequest(String eventId, String toUserId) {
    // Since Supabase queries are async, we return false here for sync UI building
    // Ideally, the UI should use a FutureBuilder or we cache sent requests locally
    return false; 
  }
}
