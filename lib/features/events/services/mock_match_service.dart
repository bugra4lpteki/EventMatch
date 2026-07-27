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

  String get currentUserId => _supabase.auth.currentUser?.id ?? 'demo_guest_user';

  List<UserModel> _potentialMatches = [];
  List<MatchRequest> _incomingRequests = [];
  bool _isDoubleDateMode = false;
  bool get isDoubleDateMode => _isDoubleDateMode;

  MockMatchService(this.eventService) {
    loadPotentialMatches();
    loadIncomingRequests();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _ensureUserInDatabase();
        loadPotentialMatches();
        loadIncomingRequests();
      } else {
        _potentialMatches.clear();
        _incomingRequests.clear();
        notifyListeners();
      }
    });
  }

  /// Oturum açmış kullanıcının public.users veritabanı kaydını garanti eder
  Future<void> _ensureUserInDatabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        final name = user.userMetadata?['name'] ??
            user.email?.split('@').first ??
            'Yeni Kullanıcı';
        final username = user.userMetadata?['username'] ??
            user.email?.split('@').first ??
            user.id.substring(0, 8);

        await _supabase.from('users').insert({
          'id': user.id,
          'name': name,
          'username': username,
        });
        debugPrint('[MatchService] ➕ Otomatik public.users profili oluşturuldu: ${user.id}');
      }
    } catch (e) {
      debugPrint('[MatchService] ⚠️ ensureUserInDatabase hatası: $e');
    }
  }

  /// Test için kullanıcının geçmiş kaydırma/beğeni etkileşimlerini veritabanından sıfırlar
  Future<void> resetSwipes() async {
    try {
      final currentId = currentUserId;
      if (currentId.isNotEmpty && _supabase.auth.currentUser != null) {
        await _supabase
            .from('matches')
            .delete()
            .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');
        debugPrint('[MatchService] 🔄 Test etkileşimleri sıfırlandı: $currentId');
      }
    } catch (e) {
      debugPrint('[MatchService] ⚠️ resetSwipes hatası: $e');
    }
    await loadPotentialMatches();
  }

  // --- SUPABASE INTEGRATION ---

  Future<void> loadPotentialMatches() async {
    try {
      _potentialMatches.clear();
      final excludedUserIds = <String>{};

      if (_supabase.auth.currentUser != null) {
        await _ensureUserInDatabase();
        final currentId = currentUserId;
        excludedUserIds.add(currentId.toLowerCase());

        debugPrint('[MatchService] 🔍 loadPotentialMatches currentUser: $currentId');

        try {
          // 1. Benim daha önce kaydırdığım tüm kayıtlar
          final mySwipes = await _supabase
              .from('matches')
              .select('user_id_2')
              .eq('user_id_1', currentId);

          for (var row in mySwipes) {
            if (row['user_id_2'] != null) {
              excludedUserIds.add(row['user_id_2'].toString().toLowerCase());
            }
          }

          // 2. Zaten eşleşmiş veya reddedilmiş olan kayıtlar
          final matchedOrRejected = await _supabase
              .from('matches')
              .select('user_id_1, status')
              .eq('user_id_2', currentId)
              .inFilter('status', ['matched', 'rejected']);

          for (var row in matchedOrRejected) {
            if (row['user_id_1'] != null) {
              excludedUserIds.add(row['user_id_1'].toString().toLowerCase());
            }
          }

          debugPrint('[MatchService] Hariç tutulacak ID sayısı: ${excludedUserIds.length}');
        } catch (e) {
          debugPrint('[MatchService] ⚠️ matches filtresi hatası: $e');
        }

        // 3. Platformdaki TÜM diğer GERÇEK kullanıcı profillerini çek
        List<Map<String, dynamic>> rawProfiles = [];
        try {
          rawProfiles = await _supabase.from('users').select();
          debugPrint('[MatchService] users tablosundan ${rawProfiles.length} kayıt çekildi');
        } catch (e) {
          try {
            rawProfiles = await _supabase.from('user_profiles').select();
          } catch (e2) {
            debugPrint('[MatchService] ❌ user_profiles hatası: $e2');
          }
        }

        final filteredProfiles = <Map<String, dynamic>>[];
        final filteredUserIds = <String>[];

        for (var p in rawProfiles) {
          final pId = (p['id'] ?? p['user_id'])?.toString();
          if (pId != null && !excludedUserIds.contains(pId.toLowerCase())) {
            filteredProfiles.add(p);
            filteredUserIds.add(pId);
          }
        }

        debugPrint('[MatchService] Deste için uygun profil sayısı: ${filteredProfiles.length}');

        // 4. Fotoğrafları ve Sosyal Medya Bağlantılarını çek
        Map<String, List<String>> userPhotosMap = {};
        Map<String, List<String>> userSocialLinksMap = {};

        if (filteredUserIds.isNotEmpty) {
          try {
            final photosRes = await _supabase
                .from('user_photos')
                .select('user_id, storage_url')
                .inFilter('user_id', filteredUserIds)
                .eq('is_active', true)
                .order('sort_order', ascending: true);

            for (var photo in photosRes) {
              final uId = photo['user_id'].toString();
              final url = photo['storage_url'].toString();
              userPhotosMap.putIfAbsent(uId, () => []).add(url);
            }
          } catch (e) {
            debugPrint('[MatchService] ⚠️ user_photos hatası: $e');
          }

          try {
            final socialRes = await _supabase
                .from('user_social_links')
                .select('user_id, url')
                .inFilter('user_id', filteredUserIds);

            for (var link in socialRes) {
              final uId = link['user_id'].toString();
              final url = link['url'].toString();
              userSocialLinksMap.putIfAbsent(uId, () => []).add(url);
            }
          } catch (e) {
            debugPrint('[MatchService] ⚠️ user_social_links hatası: $e');
          }
        }

        // 5. Kullanıcı modellerini oluştur
        for (var row in filteredProfiles) {
          final id = (row['id'] ?? row['user_id']).toString();
          final name = row['name'] ?? 'Kullanıcı $id';
          final username = row['username'];
          final bio = row['bio'] ?? row['about_me'] ?? '';
          final city = row['city'] ?? '';
          final gender = row['gender'] ?? '';

          DateTime? birthDate;
          if (row['birth_date'] != null) {
            birthDate = DateTime.tryParse(row['birth_date'].toString());
          }

          final List<String> avatarUrls = userPhotosMap[id] ?? [];
          final String avatarUrl = avatarUrls.isNotEmpty
              ? avatarUrls.first
              : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600';

          List<String> socialLinks = List<String>.from(userSocialLinksMap[id] ?? []);

          // Eğer users tablosunda da instagram/social_links sütunu varsa oku
          if (row['instagram'] != null && row['instagram'].toString().isNotEmpty) {
            final insta = row['instagram'].toString();
            if (!socialLinks.any((s) => s.contains(insta))) {
              socialLinks.add('instagram.com/$insta');
            }
          }
          if (row['social_links'] != null) {
            if (row['social_links'] is List) {
              for (var s in row['social_links']) {
                if (s != null && !socialLinks.contains(s.toString())) {
                  socialLinks.add(s.toString());
                }
              }
            }
          }

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
            socialLinks: socialLinks,
          ));
        }
      }

      // Eğer kaydırılacak gerçek profil kalmadıysa veya az ise deste boş kalmasın diye fallback profiller ekle
      if (_potentialMatches.isEmpty) {
        _addFallbackMatchesIfNeeded(excludedUserIds);
      }

      _potentialMatches.shuffle();
      notifyListeners();
    } catch (e) {
      debugPrint('Load Potential Matches Error: $e');
      _potentialMatches.clear();
      notifyListeners();
    }
  }

  void _addFallbackMatchesIfNeeded(Set<String> excludedUserIds) {
    final demoUsers = [
      UserModel(
        id: 'mock_user_1',
        name: 'Selin Yılmaz',
        username: 'selin_y',
        avatarUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=600',
        aboutMe: 'Konser ve açık hava etkinliklerini kaçırmam! 🎵',
        city: 'İstanbul',
        gender: 'Kadın',
        tags: ['Konser', 'Müzik', 'Kahve', 'Sanat'],
        badges: ['Müzik Tutkunu'],
        socialLinks: ['instagram.com/selin_y'],
      ),
      UserModel(
        id: 'mock_user_2',
        name: 'Deniz Kaya',
        username: 'deniz_k',
        avatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=600',
        aboutMe: 'Sinema, tiyatro ve doğa yürüyüşü tutkunu. 🎬🍿',
        city: 'İstanbul',
        gender: 'Erkek',
        tags: ['Sinema', 'Tiyatro', 'Spor'],
        badges: ['Sinema Sever'],
        socialLinks: ['instagram.com/deniz_k'],
      ),
      UserModel(
        id: 'mock_user_3',
        name: 'Zeynep Demir',
        username: 'zeynep_d',
        avatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=600',
        aboutMe: 'Stand-up geceleri ve techno festivaller tercihim! 🔥',
        city: 'İstanbul',
        gender: 'Kadın',
        tags: ['Stand-up', 'Techno', 'Spor'],
        badges: ['Sahne Tozu Yutmuş'],
        socialLinks: ['instagram.com/zeynep_d'],
      ),
    ];

    for (var demo in demoUsers) {
      if (!excludedUserIds.contains(demo.id.toLowerCase()) &&
          !_potentialMatches.any((m) => m.id == demo.id)) {
        _potentialMatches.add(demo);
      }
    }
  }

  // --- SWIPE / MATCH LOGIC ---

  Future<bool> swipeRight(UserModel targetUser, {String? initialMessage}) async {
    bool isMutualMatch = false;

    try {
      final currentId = currentUserId;

      debugPrint('[MatchService] ➡️ swipeRight: $currentId -> ${targetUser.id}');

      String? eventId;
      try {
        final sharedEvents = await _supabase
            .from('event_attendees')
            .select('event_id')
            .eq('user_id', targetUser.id)
            .eq('status', 'joined');

        if (sharedEvents.isNotEmpty) {
          eventId = sharedEvents.first['event_id']?.toString();
        }
      } catch (_) {}

      if (_supabase.auth.currentUser != null) {
        final existingIncomingLikes = await _supabase
            .from('matches')
            .select()
            .eq('user_id_1', targetUser.id)
            .eq('user_id_2', currentId)
            .eq('status', 'liked');

        if (existingIncomingLikes.isNotEmpty) {
          final matchRow = existingIncomingLikes.first;
          final matchRowId = matchRow['id'];

          try {
            await _supabase
                .from('matches')
                .update({'status': 'matched'})
                .eq('id', matchRowId);
          } catch (_) {
            final matchData = <String, dynamic>{
              'user_id_1': currentId,
              'user_id_2': targetUser.id,
              'status': 'matched',
            };
            if (eventId != null) matchData['event_id'] = eventId;
            await _supabase.from('matches').insert(matchData);
          }

          if (initialMessage != null && initialMessage.trim().isNotEmpty) {
            try {
              await _supabase.from('messages').insert({
                'match_id': matchRowId,
                'sender_id': currentId,
                'content': initialMessage.trim(),
              });
            } catch (e) {
              debugPrint('[MatchService] initialMessage kaydetme hatası: $e');
            }
          }

          isMutualMatch = true;
          debugPrint('[MatchService] 🎉 Karşılıklı Eşleşme Başarılı! Match ID: $matchRowId');
        } else {
          final matchData = <String, dynamic>{
            'user_id_1': currentId,
            'user_id_2': targetUser.id,
            'status': 'liked',
          };
          if (eventId != null) matchData['event_id'] = eventId;

          try {
            final insertedMatch = await _supabase.from('matches').insert(matchData).select().maybeSingle();
            if (initialMessage != null && initialMessage.trim().isNotEmpty && insertedMatch != null) {
              await _supabase.from('messages').insert({
                'match_id': insertedMatch['id'],
                'sender_id': currentId,
                'content': initialMessage.trim(),
              });
            }
          } catch (e) {
            debugPrint('[MatchService] Beğeni/Mesaj veritabanı ekleme hatası: $e');
          }

          debugPrint('[MatchService] 👍 Beğeni ve mesaj kaydedildi: $currentId -> ${targetUser.id}');
        }
      } else {
        isMutualMatch = true;
      }

      _potentialMatches.removeWhere((u) => u.id == targetUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Right Error: $e');
    }

    return isMutualMatch;
  }

  Future<void> swipeLeft(UserModel targetUser) async {
    try {
      final currentId = currentUserId;

      if (_supabase.auth.currentUser != null) {
        String? eventId;
        try {
          final sharedEvents = await _supabase
              .from('event_attendees')
              .select('event_id')
              .eq('user_id', targetUser.id)
              .eq('status', 'joined');

          if (sharedEvents.isNotEmpty) {
            eventId = sharedEvents.first['event_id']?.toString();
          }
        } catch (_) {}

        final matchData = <String, dynamic>{
          'user_id_1': currentId,
          'user_id_2': targetUser.id,
          'status': 'rejected',
        };
        if (eventId != null) matchData['event_id'] = eventId;

        await _supabase.from('matches').insert(matchData);
      }

      _potentialMatches.removeWhere((u) => u.id == targetUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Left Error: $e');
    }
  }

  // --- INCOMING REQUESTS ---

  List<MatchRequest> get incomingRequests => _incomingRequests;

  Future<void> loadIncomingRequests() async {
    try {
      final currentId = currentUserId;
      if (_supabase.auth.currentUser == null) return;

      final res = await _supabase
          .from('matches')
          .select('*, users!user_id_1(*)')
          .eq('user_id_2', currentId)
          .eq('status', 'liked');

      _incomingRequests.clear();

      for (var row in res) {
        final fromUserId = row['user_id_1'].toString();
        final eventId = row['event_id']?.toString() ?? '';
        final matchId = row['id'].toString();

        final profile = row['users'];
        final name = profile?['name'] ?? 'Kullanıcı $fromUserId';
        final avatarUrl = profile?['avatar_url'] ??
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=600';

        final fromUser = UserModel(
          id: fromUserId,
          name: name,
          avatarUrl: avatarUrl,
        );

        final currentUserModel = UserModel(
          id: currentId,
          name: 'Ben',
          avatarUrl: '',
        );

        _incomingRequests.add(MatchRequest(
          id: matchId,
          fromUser: fromUser,
          toUser: currentUserModel,
          eventId: eventId,
        ));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Load Incoming Requests Error: $e');
      _incomingRequests.clear();
      notifyListeners();
    }
  }

  Future<bool> acceptRequest(MatchRequest request) async {
    try {
      if (_supabase.auth.currentUser != null) {
        await _supabase
            .from('matches')
            .update({'status': 'matched'})
            .eq('id', request.id);
      }
      _incomingRequests.removeWhere((r) => r.id == request.id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Accept Request Error: $e');
      return false;
    }
  }

  Future<void> rejectRequest(MatchRequest request) async {
    try {
      if (_supabase.auth.currentUser != null) {
        await _supabase
            .from('matches')
            .update({'status': 'rejected'})
            .eq('id', request.id);
      }
      _incomingRequests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Reject Request Error: $e');
    }
  }

  List<UserModel> getPotentialMatches() => _potentialMatches;

  void toggleDoubleDateMode() {
    _isDoubleDateMode = !_isDoubleDateMode;
    notifyListeners();
  }

  List<GroupModel> getPotentialGroups() => [];

  void sendRequest(String eventId, UserModel toUser) {
    swipeRight(toUser);
  }

  bool hasSentRequest(String eventId, String toUserId) {
    return false;
  }
}
