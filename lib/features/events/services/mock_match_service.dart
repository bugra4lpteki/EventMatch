import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Set<String> _seenUserIds = {};
  final Set<String> _sentRequestKeys = {};
  bool _isDoubleDateMode = false;
  bool get isDoubleDateMode => _isDoubleDateMode;

  MockMatchService(this.eventService) {
    _initMatchService();
  }

  Future<void> _initMatchService() async {
    await _loadCachedRequests();
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
        _seenUserIds.clear();
        _sentRequestKeys.clear();
        notifyListeners();
      }
    });
  }

  Future<void> _loadCachedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('cached_incoming_requests_$currentUserId');
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final loaded = <MatchRequest>[];
        final seen = <String>{};

        for (var item in list) {
          try {
            final req = MatchRequest.fromMap(Map<String, dynamic>.from(item));
            if (!seen.contains(req.fromUser.id.toLowerCase())) {
              seen.add(req.fromUser.id.toLowerCase());
              loaded.add(req);
            }
          } catch (_) {}
        }
        _incomingRequests = loaded;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveCachedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _incomingRequests.map((r) => r.toMap()).toList();
      await prefs.setString('cached_incoming_requests_$currentUserId', jsonEncode(list));
    } catch (_) {}
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

  /// Test için kullanıcının geçmiş kaydırma/beğeni etkileşimlerini sıfırlar
  Future<void> resetSwipes() async {
    try {
      final currentId = currentUserId;
      _seenUserIds.clear();
      _sentRequestKeys.clear();

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

  // --- 1. POTENTIAL MATCHES & DECK DEDUPLICATION ---

  Future<void> loadPotentialMatches() async {
    try {
      _potentialMatches.clear();
      final excludedUserIds = <String>{};

      final currentId = currentUserId;
      excludedUserIds.add(currentId.toLowerCase());
      excludedUserIds.addAll(_seenUserIds.map((id) => id.toLowerCase()));

      if (_supabase.auth.currentUser != null) {
        await _ensureUserInDatabase();

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
        } catch (e) {
          debugPrint('[MatchService] ⚠️ matches filtresi hatası: $e');
        }

        // 3. Platformdaki TÜM diğer GERÇEK kullanıcı profillerini çek
        List<Map<String, dynamic>> rawProfiles = [];
        try {
          rawProfiles = await _supabase.from('users').select();
        } catch (e) {
          try {
            rawProfiles = await _supabase.from('user_profiles').select();
          } catch (e2) {
            debugPrint('[MatchService] ❌ user_profiles hatası: $e2');
          }
        }

        final filteredProfiles = <Map<String, dynamic>>[];
        final filteredUserIds = <String>[];
        final seenProfilesInDeck = <String>{};

        for (var p in rawProfiles) {
          final pId = (p['id'] ?? p['user_id'] ?? p['m_id'] ?? p['match_id'] ?? p['M_ID'])?.toString();
          if (pId != null && pId.isNotEmpty) {
            final lowerPId = pId.toLowerCase();
            if (!excludedUserIds.contains(lowerPId) && !seenProfilesInDeck.contains(lowerPId)) {
              seenProfilesInDeck.add(lowerPId);
              filteredProfiles.add(p);
              filteredUserIds.add(pId);
            }
          }
        }

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
              final uId = photo['user_id']?.toString() ?? '';
              final url = photo['storage_url']?.toString() ?? '';
              if (uId.isNotEmpty && url.isNotEmpty) {
                userPhotosMap.putIfAbsent(uId.toLowerCase(), () => []).add(url);
              }
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
              final uId = link['user_id']?.toString() ?? '';
              final url = link['url']?.toString() ?? '';
              if (uId.isNotEmpty && url.isNotEmpty) {
                userSocialLinksMap.putIfAbsent(uId.toLowerCase(), () => []).add(url);
              }
            }
          } catch (e) {
            debugPrint('[MatchService] ⚠️ user_social_links hatası: $e');
          }
        }

        // 5. Kullanıcı modellerini oluştur (Gerçek fotoğraf yoksa boş bırak, AI/Unsplash basma!)
        for (var row in filteredProfiles) {
          final id = (row['id'] ?? row['user_id'] ?? row['m_id'] ?? row['match_id'] ?? row['M_ID'] ?? '').toString();
          if (id.isEmpty) continue;

          final name = row['name']?.toString() ?? 'Kullanıcı $id';
          final username = row['username']?.toString();
          final bio = row['bio']?.toString() ?? row['about_me']?.toString() ?? '';
          final city = row['city']?.toString() ?? '';
          final gender = row['gender']?.toString() ?? '';

          DateTime? birthDate;
          if (row['birth_date'] != null) {
            birthDate = DateTime.tryParse(row['birth_date'].toString());
          }

          final List<String> avatarUrls = userPhotosMap[id.toLowerCase()] ?? [];
          final String avatarUrl = avatarUrls.isNotEmpty
              ? avatarUrls.first
              : (row['avatar_url']?.toString() ?? '');

          List<String> socialLinks = List<String>.from(userSocialLinksMap[id.toLowerCase()] ?? []);

          if (row['instagram'] != null && row['instagram'].toString().isNotEmpty) {
            final insta = row['instagram'].toString();
            if (!socialLinks.any((s) => s.contains(insta))) {
              socialLinks.add('instagram.com/$insta');
            }
          }
          if (row['social_links'] != null && row['social_links'] is List) {
            for (var s in row['social_links']) {
              if (s != null && !socialLinks.contains(s.toString())) {
                socialLinks.add(s.toString());
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

      _potentialMatches.shuffle();
      notifyListeners();
    } catch (e) {
      debugPrint('Load Potential Matches Error: $e');
      _potentialMatches.clear();
      notifyListeners();
    }
  }

  bool _isValidUuid(String str) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(str);
  }

  // --- 2. SWIPE / LIKE DEDUPLICATION ---

  Future<bool> swipeRight(UserModel targetUser, {String? initialMessage}) async {
    bool isMutualMatch = false;

    try {
      final currentId = currentUserId;
      _seenUserIds.add(targetUser.id.toLowerCase());
      _sentRequestKeys.add(targetUser.id);

      debugPrint('[MatchService] ➡️ swipeRight: $currentId -> ${targetUser.id}');

      String? eventId;
      try {
        if (_isValidUuid(targetUser.id)) {
          final sharedEvents = await _supabase
              .from('event_attendees')
              .select('event_id')
              .eq('user_id', targetUser.id)
              .eq('status', 'joined');

          if (sharedEvents.isNotEmpty) {
            eventId = sharedEvents.first['event_id']?.toString();
          }
        }
      } catch (_) {}

      if (_supabase.auth.currentUser != null && _isValidUuid(currentId) && _isValidUuid(targetUser.id)) {
        try {
          // Çift kayıt oluşmaması için önce mevcut kaydı kontrol et
          final existingMatch = await _supabase
              .from('matches')
              .select()
              .or('and(user_id_1.eq.$currentId,user_id_2.eq.${targetUser.id}),and(user_id_1.eq.${targetUser.id},user_id_2.eq.$currentId)')
              .maybeSingle();

          if (existingMatch != null) {
            final matchRowId = existingMatch['id'];
            final existingStatus = existingMatch['status']?.toString();
            final u1 = existingMatch['user_id_1']?.toString() ?? '';

            // Eğer karşı taraf beni daha önce beğenmişse -> matched yap
            if (u1.toLowerCase() == targetUser.id.toLowerCase() && existingStatus == 'liked') {
              await _supabase
                  .from('matches')
                  .update({'status': 'matched'})
                  .eq('id', matchRowId);
              isMutualMatch = true;
            } else if (existingStatus == 'matched') {
              isMutualMatch = true;
            }

            if (initialMessage != null && initialMessage.trim().isNotEmpty) {
              try {
                await _supabase.from('messages').insert({
                  'match_id': matchRowId,
                  'sender_id': currentId,
                  'receiver_id': targetUser.id,
                  'content': initialMessage.trim(),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                });
              } catch (_) {}
            }
          } else {
            // Kayıt yoksa yeni 'liked' isteği oluştur
            final matchData = <String, dynamic>{
              'user_id_1': currentId,
              'user_id_2': targetUser.id,
              'status': 'liked',
            };
            if (eventId != null) matchData['event_id'] = eventId;

            final inserted = await _supabase.from('matches').insert(matchData).select().maybeSingle();
            final matchRowId = inserted?['id'];

            if (initialMessage != null && initialMessage.trim().isNotEmpty && matchRowId != null) {
              try {
                await _supabase.from('messages').insert({
                  'match_id': matchRowId,
                  'sender_id': currentId,
                  'receiver_id': targetUser.id,
                  'content': initialMessage.trim(),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                });
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('[MatchService] Supabase swipe hatası: $e');
        }
      } else {
        isMutualMatch = true;
      }

      _potentialMatches.removeWhere((u) => u.id.toLowerCase() == targetUser.id.toLowerCase());
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Right Error: $e');
    }

    return isMutualMatch;
  }

  Future<void> swipeLeft(UserModel targetUser) async {
    try {
      final currentId = currentUserId;
      _seenUserIds.add(targetUser.id.toLowerCase());

      if (_supabase.auth.currentUser != null && _isValidUuid(currentId) && _isValidUuid(targetUser.id)) {
        try {
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
        } catch (e) {
          debugPrint('[MatchService] Swipe left Supabase hatası: $e');
        }
      }

      _potentialMatches.removeWhere((u) => u.id.toLowerCase() == targetUser.id.toLowerCase());
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Left Error: $e');
    }
  }

  // --- 3. INCOMING REQUESTS & DEDUPLICATION ---

  List<MatchRequest> get incomingRequests => _incomingRequests;

  Future<void> loadIncomingRequests() async {
    try {
      final currentId = currentUserId;
      _incomingRequests.clear();

      if (_supabase.auth.currentUser != null) {
        final res = await _supabase
            .from('matches')
            .select('*, users!user_id_1(*)')
            .eq('user_id_2', currentId)
            .eq('status', 'liked');

        final seenRequesters = <String>{};

        for (var row in res) {
          final fromUserId = (row['user_id_1'] ?? '').toString();
          if (fromUserId.isEmpty) continue;

          // Aynı kullanıcıdan gelen çift istekleri filtrele
          if (seenRequesters.contains(fromUserId.toLowerCase())) continue;
          seenRequesters.add(fromUserId.toLowerCase());

          final eventId = row['event_id']?.toString() ?? '';
          final matchId = (row['id'] ?? row['match_id'] ?? row['m_id'] ?? row['M_ID'] ?? '').toString();

          final profile = row['users'];
          final name = profile?['name']?.toString() ?? 'Kullanıcı $fromUserId';
          final avatarUrl = profile?['avatar_url']?.toString() ?? '';

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
      }

      _saveCachedRequests();
      notifyListeners();
    } catch (e) {
      debugPrint('Load Incoming Requests Error: $e');
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
      _saveCachedRequests();
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
      _saveCachedRequests();
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
    _sentRequestKeys.add('${eventId}_${toUser.id}');
    _sentRequestKeys.add(toUser.id);
    swipeRight(toUser);
    notifyListeners();
  }

  bool hasSentRequest(String eventId, String toUserId) {
    return _sentRequestKeys.contains('${eventId}_$toUserId') || _sentRequestKeys.contains(toUserId);
  }

  void clearMatchData() {
    _potentialMatches.clear();
    _incomingRequests.clear();
    _seenUserIds.clear();
    _sentRequestKeys.clear();
    notifyListeners();
  }
}
