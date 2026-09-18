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

  String get currentUserId =>
      _supabase.auth.currentUser?.id ??
      (eventService.currentUser.id.isNotEmpty ? eventService.currentUser.id : 'demo_guest_user');

  List<UserModel> _potentialMatches = [];
  List<MatchRequest> _incomingRequests = [];
  final Set<String> _seenUserIds = {};
  final Set<String> _sentRequestKeys = {};
  bool _isDoubleDateMode = false;
  bool get isDoubleDateMode => _isDoubleDateMode;
  bool _isLoadingMatches = false;
  RealtimeChannel? _matchesChannel;

  MockMatchService(this.eventService) {
    _initMatchService();
  }

  Future<void> _initMatchService() async {
    await _loadCachedSeenUsers();
    await _loadCachedRequests();
    loadPotentialMatches();
    loadIncomingRequests();
    _subscribeToRealtimeMatches();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _ensureUserInDatabase();
        _loadCachedSeenUsers();
        loadPotentialMatches();
        loadIncomingRequests();
        _subscribeToRealtimeMatches();
      } else {
        _matchesChannel?.unsubscribe();
        _matchesChannel = null;
        _potentialMatches.clear();
        _incomingRequests.clear();
        _seenUserIds.clear();
        _sentRequestKeys.clear();
        notifyListeners();
      }
    });
  }

  void _subscribeToRealtimeMatches() {
    try {
      _matchesChannel?.unsubscribe();
      final currentId = currentUserId.toLowerCase().trim();
      if (currentId.isEmpty) return;

      _matchesChannel = _supabase
          .channel('public_matches_incoming_stream_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            callback: (payload) {
              final rec = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
              final u2 = (rec['user_id_2']?.toString() ?? '').toLowerCase().trim();
              final u1 = (rec['user_id_1']?.toString() ?? '').toLowerCase().trim();
              final me = currentUserId.toLowerCase().trim();
              if (u2 == me || u1 == me) {
                debugPrint('[MatchService] 🔔 Realtime matches değişikliği, istekler yenileniyor...');
                loadIncomingRequests();
                loadPotentialMatches();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final rec = payload.newRecord;
              final rId = (rec['receiver_id']?.toString() ?? '').toLowerCase().trim();
              final me = currentUserId.toLowerCase().trim();
              if (rId == me) {
                loadIncomingRequests();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[MatchService] ⚠️ Realtime match subscription error: $e');
    }
  }

  Future<void> _loadCachedSeenUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('cached_seen_user_ids_$currentUserId');
      if (list != null) {
        _seenUserIds.addAll(list.map((e) => e.toLowerCase().trim()));
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
    if (_isLoadingMatches) return;
    _isLoadingMatches = true;

    try {
      final excludedUserIds = <String>{};
      final currentId = currentUserId.toLowerCase().trim();
      if (currentId.isNotEmpty) {
        excludedUserIds.add(currentId);
      }
      excludedUserIds.addAll(_seenUserIds.map((id) => id.toLowerCase().trim()));

      final List<UserModel> loadedMatches = [];

      if (_supabase.auth.currentUser != null) {
        await _ensureUserInDatabase();

        try {
          // 1. Zaten eşleştiğim, beğendiğim, reddettiğim veya bana gelen TÜM kayıtları iki yönde de hariç tut!
          final allMyMatches = await _supabase
              .from('matches')
              .select('user_id_1, user_id_2, status')
              .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');

          for (var row in allMyMatches) {
            final u1 = row['user_id_1']?.toString().trim() ?? '';
            final u2 = row['user_id_2']?.toString().trim() ?? '';
            final other = u1.toLowerCase() == currentId ? u2 : u1;
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
              final s = row['sender_id']?.toString().trim() ?? '';
              final r = row['receiver_id']?.toString().trim() ?? '';
              final other = s.toLowerCase() == currentId ? r : s;
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
          final pId = (p['id'] ?? p['user_id'] ?? p['m_id'] ?? p['match_id'] ?? p['M_ID'])?.toString().trim();
          if (pId != null && pId.isNotEmpty) {
            final lowerPId = pId.toLowerCase();
            if (!excludedUserIds.contains(lowerPId) && !_seenUserIds.contains(lowerPId) && !seenProfilesInDeck.contains(lowerPId)) {
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
              final uId = photo['user_id']?.toString().trim() ?? '';
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
              final uId = link['user_id']?.toString().trim() ?? '';
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
        final addedIds = <String>{};
        for (var row in filteredProfiles) {
          final id = (row['id'] ?? row['user_id'] ?? row['m_id'] ?? row['match_id'] ?? row['M_ID'] ?? '').toString().trim();
          final lowerId = id.toLowerCase();
          if (lowerId.isEmpty || addedIds.contains(lowerId) || excludedUserIds.contains(lowerId) || _seenUserIds.contains(lowerId)) {
            continue;
          }
          addedIds.add(lowerId);

          final name = row['name']?.toString() ?? 'Kullanıcı $id';
          final username = row['username']?.toString();
          final bio = row['bio']?.toString() ?? row['about_me']?.toString() ?? '';
          final city = row['city']?.toString() ?? '';
          final gender = row['gender']?.toString() ?? '';

          DateTime? birthDate;
          if (row['birth_date'] != null) {
            birthDate = DateTime.tryParse(row['birth_date'].toString());
          }

          final List<String> rawAvatarUrls = userPhotosMap[id.toLowerCase()] ?? [];
          final List<String> avatarUrls = rawAvatarUrls.where(UserModel.isValidPhotoUrl).toList();
          final rawAvatar = avatarUrls.isNotEmpty
              ? avatarUrls.first
              : (row['avatar_url']?.toString() ?? '');
          final String avatarUrl = UserModel.isValidPhotoUrl(rawAvatar) ? rawAvatar : '';

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

          loadedMatches.add(UserModel(
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

      loadedMatches.shuffle();
      _potentialMatches = loadedMatches;
      notifyListeners();
    } catch (e) {
      debugPrint('Load Potential Matches Error: $e');
      _potentialMatches.clear();
      notifyListeners();
    } finally {
      _isLoadingMatches = false;
    }
  }

  bool _isValidUuid(String str) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(str);
  }

  // --- 2. SWIPE / LIKE DEDUPLICATION ---

  Future<bool> swipeRight(UserModel targetUser, {String? initialMessage}) async {
    bool isMutualMatch = false;
    final targetId = targetUser.id.toLowerCase().trim();
    final currentId = currentUserId;

    // 1. Kartı hafızadan derhal sil ve görüldü olarak kaydet (UI anında güncellenir)
    _seenUserIds.add(targetId);
    _sentRequestKeys.add(targetUser.id);
    _potentialMatches.removeWhere((u) => u.id.toLowerCase().trim() == targetId);
    _saveCachedSeenUsers();
    notifyListeners();

    debugPrint('[MatchService] ➡️ swipeRight: $currentId -> ${targetUser.id}');

    try {
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

      if (_supabase.auth.currentUser != null && currentId.trim().isNotEmpty && targetUser.id.trim().isNotEmpty) {
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
            } else if (u1.toLowerCase() == targetId && (existingStatus == 'liked' || existingStatus == 'pending')) {
              // Karşı taraf daha önce beni beğenmiş -> İki yönlü eşleşme sağlandı!
              await _supabase
                  .from('matches')
                  .update({'status': 'matched'})
                  .or('and(user_id_1.eq.$currentId,user_id_2.eq.${targetUser.id}),and(user_id_1.eq.${targetUser.id},user_id_2.eq.$currentId)');
              isMutualMatch = true;
            } else if (existingStatus != 'matched') {
              // Daha önce rejected veya tek yönlü ise isteği bu kullanıcıdan hedefe doğru 'liked' olarak güncelle
              await _supabase
                  .from('matches')
                  .update({
                    'status': 'liked',
                    'user_id_1': currentId,
                    'user_id_2': targetUser.id,
                  })
                  .eq('id', matchRowId);
            }

            if (initialMessage != null && initialMessage.trim().isNotEmpty) {
              final numMatchId = matchRowId != null ? int.tryParse(matchRowId.toString()) : null;
              try {
                await _supabase.from('messages').insert({
                  if (numMatchId != null) 'match_id': numMatchId,
                  'sender_id': currentId,
                  'receiver_id': targetUser.id,
                  'content': initialMessage.trim(),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                });
              } catch (e) {
                try {
                  await _supabase.from('messages').insert({
                    'sender_id': currentId,
                    'receiver_id': targetUser.id,
                    'content': initialMessage.trim(),
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                  });
                } catch (_) {}
              }
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

            if (initialMessage != null && initialMessage.trim().isNotEmpty) {
              final numMatchId = matchRowId != null ? int.tryParse(matchRowId.toString()) : null;
              try {
                await _supabase.from('messages').insert({
                  if (numMatchId != null) 'match_id': numMatchId,
                  'sender_id': currentId,
                  'receiver_id': targetUser.id,
                  'content': initialMessage.trim(),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                });
              } catch (e) {
                try {
                  await _supabase.from('messages').insert({
                    'sender_id': currentId,
                    'receiver_id': targetUser.id,
                    'content': initialMessage.trim(),
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                  });
                } catch (_) {}
              }
            }
          }
        } catch (e) {
          debugPrint('[MatchService] Supabase swipe hatası: $e');
        }
      } else {
        isMutualMatch = false;
      }
    } catch (e) {
      debugPrint('Swipe Right Error: $e');
    }

    return isMutualMatch;
  }

  Future<void> swipeLeft(UserModel targetUser) async {
    final targetId = targetUser.id.toLowerCase().trim();
    final currentId = currentUserId;

    // 1. Kartı hafızadan derhal sil ve görüldü olarak kaydet (UI anında güncellenir)
    _seenUserIds.add(targetId);
    _potentialMatches.removeWhere((u) => u.id.toLowerCase().trim() == targetId);
    _saveCachedSeenUsers();
    notifyListeners();

    try {
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
      final currentId = currentUserId.trim();
      final lowerCurrentId = currentId.toLowerCase();

      if (_supabase.auth.currentUser != null && currentId.isNotEmpty) {
        // 1. Zaten karşılıklı eşleştiğim kişileri tespit et (onlardan gelen yeni istek olamaz)
        final alreadyMatchedIds = <String>{};

        try {
          final existingMatches = await _supabase
              .from('matches')
              .select('user_id_1, user_id_2, status')
              .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId,user_id_1.eq.$lowerCurrentId,user_id_2.eq.$lowerCurrentId')
              .eq('status', 'matched');

          for (var m in existingMatches) {
            final u1 = (m['user_id_1'] ?? '').toString().toLowerCase().trim();
            final u2 = (m['user_id_2'] ?? '').toString().toLowerCase().trim();
            final other = u1 == lowerCurrentId ? u2 : u1;
            if (other.isNotEmpty) {
              alreadyMatchedIds.add(other);
              _seenUserIds.add(other);
            }
          }
        } catch (e) {
          debugPrint('[MatchService] existingMatches query error: $e');
        }

        // 2. Bana gelen 'liked' veya 'pending' statüsündeki kayıtları çek
        // (FOREIGN KEY JOIN KULLANMIYORUZ: matches tablosunda users foreign key yok, doğrudan select('*'))
        final userIdsToQuery = {currentId, lowerCurrentId}.where((s) => s.isNotEmpty).toList();
        List<dynamic> matchRows = [];
        try {
          matchRows = await _supabase
              .from('matches')
              .select('*')
              .inFilter('user_id_2', userIdsToQuery)
              .inFilter('status', ['liked', 'pending']);
        } catch (e) {
          debugPrint('[MatchService] Incoming matches query error: $e');
          try {
            matchRows = await _supabase
                .from('matches')
                .select('*')
                .inFilter('user_id_2', userIdsToQuery);
            matchRows = matchRows.where((r) {
              final st = r['status']?.toString().toLowerCase().trim();
              return st == 'liked' || st == 'pending';
            }).toList();
          } catch (e2) {
            debugPrint('[MatchService] Fallback incoming matches error: $e2');
          }
        }

        final requesterIds = <String>[];
        for (var row in matchRows) {
          final fromUserId = (row['user_id_1'] ?? '').toString().trim();
          final lowerFromId = fromUserId.toLowerCase();
          if (fromUserId.isNotEmpty &&
              !alreadyMatchedIds.contains(lowerFromId) &&
              lowerFromId != lowerCurrentId) {
            if (!requesterIds.contains(fromUserId)) {
              requesterIds.add(fromUserId);
            }
          }
        }

        final Map<String, Map<String, dynamic>> profilesMap = {};
        if (requesterIds.isNotEmpty) {
          try {
            final uRes = await _supabase
                .from('users')
                .select('*')
                .inFilter('id', requesterIds);
            for (var u in uRes) {
              profilesMap[u['id'].toString().toLowerCase()] = Map<String, dynamic>.from(u);
            }
          } catch (e) {
            debugPrint('[MatchService] Requester users query error: $e');
          }
        }

        final Map<String, List<String>> requesterPhotos = {};
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
              if (uId.isNotEmpty && url.isNotEmpty) {
                requesterPhotos.putIfAbsent(uId, () => []).add(url);
              }
            }
          } catch (_) {}
        }

        final loadedRequests = <MatchRequest>[];
        final seenRequesters = <String>{};

        for (var row in matchRows) {
          final fromUserId = (row['user_id_1'] ?? '').toString().trim();
          if (fromUserId.isEmpty) continue;

          final lowerFromId = fromUserId.toLowerCase();
          if (alreadyMatchedIds.contains(lowerFromId) || lowerFromId == lowerCurrentId) {
            continue;
          }

          final profile = profilesMap[lowerFromId];
          final name = profile?['name']?.toString() ?? (row['sender_name']?.toString() ?? 'Kullanıcı');

          // ID ve isim bazlı çift istek filtreleme
          final uniqueKey = '${lowerFromId}_${name.toLowerCase()}';
          if (seenRequesters.contains(uniqueKey) || seenRequesters.contains(lowerFromId)) {
            continue;
          }
          seenRequesters.add(uniqueKey);
          seenRequesters.add(lowerFromId);

          final eventId = row['event_id']?.toString() ?? '';
          final matchId = (row['id'] ?? row['match_id'] ?? '').toString();

          final rawUserPhotos = requesterPhotos[lowerFromId] ?? [];
          final userPhotos = rawUserPhotos.where(UserModel.isValidPhotoUrl).toList();
          final rawPhoto = userPhotos.isNotEmpty
              ? userPhotos.first
              : (profile?['avatar_url']?.toString() ?? '');
          final photoUrl = UserModel.isValidPhotoUrl(rawPhoto) ? rawPhoto : '';

          final fromUser = UserModel(
            id: fromUserId,
            name: name,
            username: profile?['username']?.toString() ?? (fromUserId.length > 8 ? fromUserId.substring(0, 8) : fromUserId),
            avatarUrl: photoUrl,
            avatarUrls: userPhotos,
            gender: profile?['gender']?.toString(),
            isVerified: profile?['is_verified'] == true ||
                (profile?['badges'] is List && (profile?['badges'] as List).contains('verified')),
            city: profile?['city']?.toString() ?? '',
            aboutMe: profile?['bio']?.toString() ?? '',
          );

          final currentUserModel = UserModel(
            id: currentId,
            name: eventService.currentUser.name.isNotEmpty ? eventService.currentUser.name : 'Ben',
            avatarUrl: eventService.currentUser.avatarUrl,
          );

          String? initialMessage;
          try {
            final numericId = int.tryParse(matchId);
            if (numericId != null) {
              final msgRes = await _supabase
                  .from('messages')
                  .select('content')
                  .eq('match_id', numericId)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
              if (msgRes != null && msgRes['content'] != null) {
                initialMessage = msgRes['content'].toString();
              }
            }
            if (initialMessage == null || initialMessage.isEmpty) {
              final directMsg = await _supabase
                  .from('messages')
                  .select('content')
                  .eq('sender_id', fromUserId)
                  .eq('receiver_id', currentId)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
              if (directMsg != null && directMsg['content'] != null) {
                initialMessage = directMsg['content'].toString();
              }
            }
          } catch (_) {}

          loadedRequests.add(MatchRequest(
            id: matchId,
            fromUser: fromUser,
            toUser: currentUserModel,
            eventId: eventId,
            message: initialMessage,
          ));
        }

        _incomingRequests = loadedRequests;
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
        final numericId = int.tryParse(request.id);
        if (numericId != null) {
          await _supabase.from('matches').update({'status': 'matched'}).eq('id', numericId);
        } else {
          await _supabase
              .from('matches')
              .update({'status': 'matched'})
              .or('and(user_id_1.eq.$partnerId,user_id_2.eq.$currentId),and(user_id_1.eq.$currentId,user_id_2.eq.$partnerId)');
        }
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
        final numericId = int.tryParse(request.id);
        if (numericId != null) {
          await _supabase.from('matches').update({'status': 'rejected'}).eq('id', numericId);
        } else {
          await _supabase
              .from('matches')
              .update({'status': 'rejected'})
              .or('and(user_id_1.eq.$partnerId,user_id_2.eq.$currentId),and(user_id_1.eq.$currentId,user_id_2.eq.$partnerId)');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Reject Request Error: $e');
    }
  }

  @override
  void dispose() {
    _matchesChannel?.unsubscribe();
    super.dispose();
  }

  List<UserModel> getPotentialMatches() {
    final seen = <String>{};
    final result = <UserModel>[];
    for (final u in _potentialMatches) {
      final cleanId = u.id.toLowerCase().trim();
      if (cleanId.isEmpty) continue;
      if (_seenUserIds.contains(cleanId)) continue;
      if (seen.contains(cleanId)) continue;
      seen.add(cleanId);
      result.add(u);
    }
    return result;
  }

  void toggleDoubleDateMode() {
    _isDoubleDateMode = !_isDoubleDateMode;
    notifyListeners();
  }

  List<GroupModel> getPotentialGroups() => [];

  Future<bool> sendRadarRequest(UserModel toUser) async {
    _sentRequestKeys.add('radar_${toUser.id}');
    _sentRequestKeys.add(toUser.id);
    final isMutual = await swipeRight(toUser);
    notifyListeners();
    return isMutual;
  }

  Future<bool> sendRequest(String eventId, UserModel toUser) async {
    _sentRequestKeys.add('${eventId}_${toUser.id}');
    _sentRequestKeys.add(toUser.id);
    final isMutual = await swipeRight(toUser);
    notifyListeners();
    return isMutual;
  }

  bool hasSentRequest(String eventId, String toUserId) {
    return _sentRequestKeys.contains('${eventId}_$toUserId') ||
           _sentRequestKeys.contains(toUserId) ||
           _sentRequestKeys.contains('radar_$toUserId');
  }

  void clearMatchData() {
    _potentialMatches.clear();
    _incomingRequests.clear();
    _seenUserIds.clear();
    _sentRequestKeys.clear();
    notifyListeners();
  }
}
