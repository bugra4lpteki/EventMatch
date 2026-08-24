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
    await _loadCachedSeenUsers();
    await _loadCachedRequests();
    loadPotentialMatches();
    loadIncomingRequests();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _ensureUserInDatabase();
        _loadCachedSeenUsers();
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

  Future<void> _loadCachedSeenUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('cached_seen_user_ids_$currentUserId');
      if (list != null) {
        _seenUserIds.addAll(list.map((e) => e.toLowerCase()));
      }
    } catch (_) {}
  }

  Future<void> _saveCachedSeenUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_seen_user_ids_$currentUserId', _seenUserIds.toList());
    } catch (_) {}
  }

  void unmarkSeenUser(String userId) {
    final lowerId = userId.toLowerCase();
    _seenUserIds.remove(lowerId);
    _sentRequestKeys.remove(lowerId);
    _saveCachedSeenUsers();
    loadPotentialMatches();
    notifyListeners();
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
            // Unsplash URL'lerini temizle
            if (req.fromUser.avatarUrl.contains('unsplash.com')) {
              req.fromUser.avatarUrl = '';
            }
            final key = '${req.fromUser.id}_${req.fromUser.name}'.toLowerCase();
            if (!seen.contains(key)) {
              seen.add(key);
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
      _saveCachedSeenUsers();

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
          // 1. Zaten eşleştiğim, beğendiğim, reddettiğim veya bana gelen TÜM kayıtları iki yönde de hariç tut!
          final allMyMatches = await _supabase
              .from('matches')
              .select('user_id_1, user_id_2, status')
              .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');

          for (var row in allMyMatches) {
            final u1 = row['user_id_1']?.toString() ?? '';
            final u2 = row['user_id_2']?.toString() ?? '';
            final other = u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1;
            if (other.isNotEmpty) {
              final lowerOther = other.toLowerCase();
              excludedUserIds.add(lowerOther);
              _seenUserIds.add(lowerOther);
            }
          }

          // 2. Halihazırda mesajlaştığım kişileri de desteden kesin olarak çıkar
          try {
            final myMessages = await _supabase
                .from('messages')
                .select('sender_id, receiver_id')
                .or('sender_id.eq.$currentId,receiver_id.eq.$currentId');

            for (var row in myMessages) {
              final s = row['sender_id']?.toString() ?? '';
              final r = row['receiver_id']?.toString() ?? '';
              final other = s.toLowerCase() == currentId.toLowerCase() ? r : s;
              if (other.isNotEmpty) {
                final lowerOther = other.toLowerCase();
                excludedUserIds.add(lowerOther);
                _seenUserIds.add(lowerOther);
              }
            }
          } catch (_) {}

          _saveCachedSeenUsers();
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
      final targetId = targetUser.id.toLowerCase();
      _seenUserIds.add(targetId);
      _sentRequestKeys.add(targetUser.id);
      _saveCachedSeenUsers();

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
          // Çift kayıt oluşmaması için mevcut kayıtları kontrol et
          final List<dynamic> existingRows = await _supabase
              .from('matches')
              .select()
              .or('and(user_id_1.eq.$currentId,user_id_2.eq.${targetUser.id}),and(user_id_1.eq.${targetUser.id},user_id_2.eq.$currentId)');

          if (existingRows.isNotEmpty) {
            final firstRow = existingRows.first;
            final matchRowId = firstRow['id'];
            final existingStatus = firstRow['status']?.toString();
            final u1 = firstRow['user_id_1']?.toString() ?? '';

            if (existingStatus == 'matched') {
              isMutualMatch = true;
            } else if (u1.toLowerCase() == targetId && existingStatus == 'liked') {
              // Karşı taraf daha önce beni beğenmiş -> İki yönlü eşleşme sağlandı
              await _supabase
                  .from('matches')
                  .update({'status': 'matched'})
                  .or('and(user_id_1.eq.$currentId,user_id_2.eq.${targetUser.id}),and(user_id_1.eq.${targetUser.id},user_id_2.eq.$currentId)');
              isMutualMatch = true;
            }

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

      _potentialMatches.removeWhere((u) => u.id.toLowerCase() == targetId);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Right Error: $e');
    }

    return isMutualMatch;
  }

  Future<void> swipeLeft(UserModel targetUser) async {
    try {
      final currentId = currentUserId;
      final targetId = targetUser.id.toLowerCase();
      _seenUserIds.add(targetId);
      _saveCachedSeenUsers();

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

          final List<dynamic> existingRows = await _supabase
              .from('matches')
              .select()
              .or('and(user_id_1.eq.$currentId,user_id_2.eq.${targetUser.id}),and(user_id_1.eq.${targetUser.id},user_id_2.eq.$currentId)');

          if (existingRows.isNotEmpty) {
            await _supabase
                .from('matches')
                .update({'status': 'rejected'})
                .or('and(user_id_1.eq.$currentId,user_id_2.eq.${targetUser.id}),and(user_id_1.eq.${targetUser.id},user_id_2.eq.$currentId)');
          } else {
            final matchData = <String, dynamic>{
              'user_id_1': currentId,
              'user_id_2': targetUser.id,
              'status': 'rejected',
            };
            if (eventId != null) matchData['event_id'] = eventId;

            await _supabase.from('matches').insert(matchData);
          }
        } catch (e) {
          debugPrint('[MatchService] Swipe left Supabase hatası: $e');
        }
      }

      _potentialMatches.removeWhere((u) => u.id.toLowerCase() == targetId);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Left Error: $e');
    }
  }

  // --- 3. INCOMING REQUESTS & DEDUPLICATION ---

  List<MatchRequest> get incomingRequests {
    final seen = <String>{};
    final list = <MatchRequest>[];
    for (var r in _incomingRequests) {
      final idKey = r.fromUser.id.toLowerCase();
      final nameKey = '${r.fromUser.id}_${r.fromUser.name}'.toLowerCase();
      if (!seen.contains(nameKey) && !seen.contains(idKey)) {
        seen.add(nameKey);
        seen.add(idKey);
        list.add(r);
      }
    }
    return list;
  }

  Future<void> loadIncomingRequests() async {
    try {
      final currentId = currentUserId;
      _incomingRequests.clear();

      if (_supabase.auth.currentUser != null) {
        // 1. Zaten eşleştiğim veya mesajlaştığım kişileri tespit et (onlardan gelen yeni istek olamaz)
        final alreadyMatchedIds = <String>{};

        try {
          final existingMatches = await _supabase
              .from('matches')
              .select('user_id_1, user_id_2, status')
              .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId')
              .eq('status', 'matched');

          for (var m in existingMatches) {
            final u1 = (m['user_id_1'] ?? '').toString().toLowerCase();
            final u2 = (m['user_id_2'] ?? '').toString().toLowerCase();
            final other = u1 == currentId.toLowerCase() ? u2 : u1;
            if (other.isNotEmpty) {
              alreadyMatchedIds.add(other);
              _seenUserIds.add(other);
            }
          }
        } catch (e) {
          debugPrint('[MatchService] existingMatches query error: $e');
        }

        try {
          final myMessages = await _supabase
              .from('messages')
              .select('sender_id, receiver_id')
              .or('sender_id.eq.$currentId,receiver_id.eq.$currentId');

          for (var row in myMessages) {
            final s = (row['sender_id'] ?? '').toString().toLowerCase();
            final r = (row['receiver_id'] ?? '').toString().toLowerCase();
            final other = s == currentId.toLowerCase() ? r : s;
            if (other.isNotEmpty) {
              alreadyMatchedIds.add(other);
              _seenUserIds.add(other);
            }
          }
        } catch (e) {
          debugPrint('[MatchService] myMessages query error: $e');
        }

        // 2. Bana gelen 'liked' statüsündeki kayıtları çek
        final res = await _supabase
            .from('matches')
            .select('*, users!user_id_1(*)')
            .eq('user_id_2', currentId)
            .eq('status', 'liked');

        final requesterIds = <String>[];
        for (var row in res) {
          final fromUserId = (row['user_id_1'] ?? '').toString().toLowerCase();
          if (fromUserId.isNotEmpty &&
              _isValidUuid(fromUserId) &&
              !alreadyMatchedIds.contains(fromUserId)) {
            requesterIds.add(fromUserId);
          }
        }

        Map<String, String> requesterPhotos = {};
        if (requesterIds.isNotEmpty) {
          try {
            final photosRes = await _supabase
                .from('user_photos')
                .select('user_id, storage_url')
                .inFilter('user_id', requesterIds)
                .eq('is_active', true)
                .order('sort_order', ascending: true);

            for (var p in photosRes) {
              final uId = p['user_id']?.toString().toLowerCase() ?? '';
              final url = p['storage_url']?.toString() ?? '';
              if (!requesterPhotos.containsKey(uId) && url.isNotEmpty) {
                requesterPhotos[uId] = url;
              }
            }
          } catch (_) {}
        }

        final seenRequesters = <String>{};

        for (var row in res) {
          final fromUserId = (row['user_id_1'] ?? '').toString();
          if (fromUserId.isEmpty) continue;

          final lowerFromId = fromUserId.toLowerCase();

          // Zaten eşleşilmiş biriyse isteği filtrele ve Supabase'deki kaydı da matched yap
          if (alreadyMatchedIds.contains(lowerFromId)) {
            try {
              final rowId = row['id'];
              if (rowId != null) {
                _supabase.from('matches').update({'status': 'matched'}).eq('id', rowId);
              }
            } catch (_) {}
            continue;
          }

          final profile = row['users'];
          final name = profile?['name']?.toString() ?? 'Kullanıcı $fromUserId';

          // ID ve isim bazlı çift istek filtreleme
          final uniqueKey = '${lowerFromId}_${name.toLowerCase()}';
          if (seenRequesters.contains(uniqueKey) || seenRequesters.contains(lowerFromId)) {
            continue;
          }
          seenRequesters.add(uniqueKey);
          seenRequesters.add(lowerFromId);

          final eventId = row['event_id']?.toString() ?? '';
          final matchId = (row['id'] ?? row['match_id'] ?? row['m_id'] ?? row['M_ID'] ?? '').toString();

          final photoUrl = requesterPhotos[lowerFromId] ??
              profile?['avatar_url']?.toString() ??
              '';

          // Unsplash URL basma
          final cleanAvatarUrl = photoUrl.contains('unsplash.com') ? '' : photoUrl;

          final fromUser = UserModel(
            id: fromUserId,
            name: name,
            avatarUrl: cleanAvatarUrl,
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
      final partnerId = request.fromUser.id.toLowerCase();
      final currentId = currentUserId.toLowerCase();

      _seenUserIds.add(partnerId);
      _potentialMatches.removeWhere((u) => u.id.toLowerCase() == partnerId);
      _incomingRequests.removeWhere((r) => r.fromUser.id.toLowerCase() == partnerId || r.id == request.id);
      _saveCachedSeenUsers();
      _saveCachedRequests();

      if (_supabase.auth.currentUser != null) {
        await _supabase
            .from('matches')
            .update({'status': 'matched'})
            .or('and(user_id_1.eq.$partnerId,user_id_2.eq.$currentId),and(user_id_1.eq.$currentId,user_id_2.eq.$partnerId)');
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Accept Request Error: $e');
      return false;
    }
  }

  Future<void> rejectRequest(MatchRequest request) async {
    try {
      final partnerId = request.fromUser.id.toLowerCase();
      final currentId = currentUserId.toLowerCase();

      _seenUserIds.add(partnerId);
      _potentialMatches.removeWhere((u) => u.id.toLowerCase() == partnerId);
      _incomingRequests.removeWhere((r) => r.fromUser.id.toLowerCase() == partnerId || r.id == request.id);
      _saveCachedSeenUsers();
      _saveCachedRequests();

      if (_supabase.auth.currentUser != null) {
        await _supabase
            .from('matches')
            .update({'status': 'rejected'})
            .or('and(user_id_1.eq.$partnerId,user_id_2.eq.$currentId),and(user_id_1.eq.$currentId,user_id_2.eq.$partnerId)');
      }

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
