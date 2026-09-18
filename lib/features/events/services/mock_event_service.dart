import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import 'external_event_service.dart';

class MockEventService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _attendeesChannel;
  RealtimeChannel? _attendeesSyncChannel;
  RealtimeChannel? _venueBroadcastChannel;
  String? _activeVenueEventId;

  String get currentUserId {
    final sbId = _supabase.auth.currentUser?.id;
    if (sbId != null && sbId.isNotEmpty) return sbId;
    final sessId = _supabase.auth.currentSession?.user.id;
    if (sessId != null && sessId.isNotEmpty) return sessId;
    return currentUser.id;
  }

  bool _isValidUuid(String str) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(str);
  }

  MockEventService() {
    final sbUid = _supabase.auth.currentUser?.id;
    if (sbUid != null && sbUid.isNotEmpty) {
      currentUser.id = sbUid;
    }
    _initAuthListener();
    _loadCarouselSettings();
    _initService();
    _subscribeToAttendeesRealtime();
    _subscribeToAttendeesBroadcast();
  }

  Future<void> _initService() async {
    await loadUserProfile();
    await fetchEvents();
  }

  void _initAuthListener() {
    _authSub = _supabase.auth.onAuthStateChange.listen((data) async {
      final newUserId = data.session?.user.id;
      if (newUserId != null && newUserId.isNotEmpty) {
        currentUser.id = newUserId;
        await loadUserProfile();
        await _loadSupabaseAttendees();
        _syncPlannedEventsWithAttendees();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _attendeesChannel?.unsubscribe();
    _attendeesSyncChannel?.unsubscribe();
    _venueBroadcastChannel?.unsubscribe();
    super.dispose();
  }

  static const String _eventsCacheKey = 'eventmatch_cached_events_v5_ticketmaster_clean';

  Future<void> _saveEventsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _events.map((e) => e.toMap()).toList();
      await prefs.setString(_eventsCacheKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<bool> _loadEventsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_eventsCacheKey);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cached);
        if (decoded.isNotEmpty) {
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              final ev = EventModel.fromMap(item);
              // Geçerli olmayan, tarihi geçmiş, iptal edilmiş veya spor müsabakası olan etkinlikleri asla yükleme
              if (!ev.isValidForDisplay) {
                continue;
              }
              if (!_events.any((e) => e.id == ev.id)) {
                _events.add(ev);
              }
            }
          }
          return _events.isNotEmpty;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchEvents() async {
    // A. Anında render: Önbellek sürümü kontrolü (Eski önbelleği tamamen sil ve sıfırdan temiz Biletix verisi ile başlat)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheVersion = prefs.getInt('eventmatch_cache_version_num') ?? 0;
      if (cacheVersion < 16) {
        await prefs.remove(_eventsCacheKey);
        await prefs.setInt('eventmatch_cache_version_num', 16);
        _events.clear();
      } else {
        await _loadEventsFromCache();
      }
    } catch (_) {}

    // Tarihi geçmiş, iptal edilmiş, spor veya geçersiz harici servis etkinliklerini temizle
    _cleanObsoleteAndExpiredEvents();

    // Yalnızca önbellek veya liste tamamen boşsa başlangıç vitrin etkinliklerini ekle
    if (_events.isEmpty) {
      _populateFallbackEvents();
    }

    _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _loadLocalAttendeesCache();
    _syncPlannedEventsWithAttendees();
    // B. Arka planda sessizce Canlı Biletix API'lerini güncelle (Test ortamında timer/network sızıntısını önler)
    final bool isTestMode = const bool.fromEnvironment('flutter.test') ||
        (WidgetsBinding.instance.runtimeType.toString().contains('Test'));
    if (!isTestMode) {
      _fetchLiveEventsInBackground();
    }
  }

  void _cleanObsoleteAndExpiredEvents() {
    _events.removeWhere((e) => !e.isValidForDisplay);
  }

  Future<void> _fetchLiveEventsInBackground() async {
    try {
      // 1. Supabase'den gerçek kayıtlı katılımcıları çek
      await _loadSupabaseAttendees();
      _syncPlannedEventsWithAttendees();
      notifyListeners();

      // 2. Canlı Biletix (Ticketmaster) API'sini arka planda çek
      try {
        final service = ExternalEventService();
        // Ticketmaster API limitlerine (rate limit 5 req/sec) takılmamak için sorguları sıralı ve gecikmeli çekiyoruz
        final List<List<EventModel>> results = [];
        
        // 1. Genel Türkiye etkinlikleri (Sayfa 0 ve 1)
        final p0 = await service.fetchLiveTicketmasterEvents(page: 0, size: 100);
        results.add(p0);
        await Future.delayed(const Duration(milliseconds: 250));

        final p1 = await service.fetchLiveTicketmasterEvents(page: 1, size: 100);
        results.add(p1);
        await Future.delayed(const Duration(milliseconds: 250));

        // 2. Öne çıkan popüler aramalar (kademeli)
        final keywords = ['duman', 'teoman', 'tiyatro', 'stand up', 'festival', 'komedi', 'caz festivali'];
        for (final kw in keywords) {
          await Future.delayed(const Duration(milliseconds: 250));
          final kwResults = await service.fetchLiveTicketmasterEvents(keyword: kw, size: 20);
          if (kwResults.isNotEmpty) results.add(kwResults);
        }

        bool addedAny = false;
        final Set<String> liveBiletixIds = {};

        for (var list in results) {
          for (var live in list) {
            if (!live.isValidForDisplay) continue;
            liveBiletixIds.add(live.id);
            final idx = _events.indexWhere((e) => e.id == live.id);
            if (idx < 0) {
              _events.add(live);
              addedAny = true;
            } else {
              // Biletix'ten gelen yeni kesin tarih, saat ve bilet linkleri ile güncelle
              _events[idx] = live;
              addedAny = true;
            }
          }
        }

        // Canlı Biletix API sonuçları geldiyse:
        // 1. Canlı Biletix listesinde artık bulunmayan veya eski mock olan Biletix etkinliklerini temizle
        // 2. Tarihi geçmiş veya iptal edilmiş tüm etkinlikleri temizle
        if (liveBiletixIds.isNotEmpty) {
          _events.removeWhere((e) {
            if (!e.isValidForDisplay) return true;
            if (e.id.startsWith('biletix_') && !liveBiletixIds.contains(e.id)) {
              return true;
            }
            return false;
          });
          addedAny = true;
        }

        if (addedAny) {
          _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          await _saveEventsToCache();
          notifyListeners();
        }
        debugPrint('[EventService] 🎟️ Biletix canlı etkinlikleri senkronize edildi: ${_events.length}');
      } catch (e) {
        debugPrint('[EventService] Canlı Biletix API çekme hatası: $e');
      }

      await _saveEventsToCache();
      notifyListeners();
    } catch (e) {
      debugPrint('[EventService] Arka plan etkinlik yenileme hatası: $e');
    }
  }


  Future<void> _loadSupabaseAttendees() async {
    try {
      final rows = await _supabase.from('event_attendees').select('event_id, user_id, status').eq('status', 'joined');
      if (rows.isEmpty) return;

      final myUid = currentUserId.toLowerCase().trim();

      final userIds = rows
          .map((r) => r['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty && _isValidUuid(id))
          .cast<String>()
          .toSet()
          .toList();

      final Map<String, UserModel> usersMap = {};
      if (userIds.isNotEmpty) {
        try {
          final usersRes = await _supabase
              .from('users')
              .select('id, name, username, city, gender')
              .inFilter('id', userIds);
          for (var u in usersRes) {
            final id = u['id'].toString();
            usersMap[id.toLowerCase()] = UserModel(
              id: id,
              name: u['name']?.toString() ?? 'Kullanıcı',
              username: u['username']?.toString(),
              city: u['city']?.toString(),
              gender: u['gender']?.toString(),
              avatarUrl: '',
            );
          }
        } catch (_) {}

        try {
          final photosRes = await _supabase
              .from('user_photos')
              .select('user_id, storage_url')
              .inFilter('user_id', userIds)
              .eq('is_active', true)
              .order('sort_order', ascending: true);
          for (var p in photosRes) {
            final uid = p['user_id'].toString().toLowerCase();
            final photo = p['storage_url'].toString();
            if (usersMap.containsKey(uid) && UserModel.isValidPhotoUrl(photo) && usersMap[uid]!.avatarUrl.isEmpty) {
              usersMap[uid]!.avatarUrl = photo;
            }
          }
        } catch (_) {}
      }

      for (var row in rows) {
        final eventId = row['event_id']?.toString();
        final rawUserId = row['user_id']?.toString();
        if (eventId == null || rawUserId == null) continue;

        final lowerUserId = rawUserId.toLowerCase().trim();
        final eventIndex = _events.indexWhere((e) => e.id == eventId);
        if (eventIndex >= 0) {
          final isMe = lowerUserId == myUid;
          final userModel = isMe
              ? UserModel(
                  id: currentUserId,
                  name: currentUser.name,
                  avatarUrl: currentUser.avatarUrl,
                  city: currentUser.city,
                )
              : (usersMap[lowerUserId] ?? UserModel(id: rawUserId, name: 'Katılımcı', avatarUrl: ''));

          final existingIdx = _events[eventIndex].attendees.indexWhere((u) => u.id.toLowerCase() == lowerUserId);
          if (existingIdx >= 0) {
            _events[eventIndex].attendees[existingIdx] = userModel;
          } else {
            _events[eventIndex].attendees.add(userModel);
          }

          if (isMe && !currentUser.plannedEvents.contains(eventId)) {
            currentUser.plannedEvents.add(eventId);
          }
        }
      }
      _savePlannedEvents();
      notifyListeners();
    } on PostgrestException catch (e) {
      debugPrint('[EventService] Supabase attendees tablosuna erişilemedi (Yerel önbellek devrede): ${e.message}');
    } catch (e) {
      debugPrint('[EventService] Supabase attendees çekme hatası: $e');
    }
  }

  void _syncPlannedEventsWithAttendees() {
    final uid = currentUserId.toLowerCase().trim();
    if (uid.isEmpty) return;

    final myUser = UserModel(
      id: currentUserId,
      name: currentUser.name,
      avatarUrl: currentUser.avatarUrl,
      city: currentUser.city,
      birthDate: currentUser.birthDate,
      tags: List.from(currentUser.tags),
    );

    for (var event in _events) {
      final shouldAttend = currentUser.plannedEvents.contains(event.id);
      final hasMe = event.attendees.any((u) => u.id.toLowerCase().trim() == uid);

      if (shouldAttend && !hasMe) {
        event.attendees.insert(0, myUser);
      } else if (!shouldAttend && hasMe) {
        event.attendees.removeWhere((u) => u.id.toLowerCase().trim() == uid);
      }
    }
  }

  Future<void> _saveEventAttendeesLocally(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex >= 0) {
        final attendeesData = _events[eventIndex].attendees.map((u) => {
          'id': u.id,
          'name': u.name,
          'avatarUrl': u.avatarUrl,
          'city': u.city,
        }).toList();
        await prefs.setString('eventmatch_attendees_$eventId', jsonEncode(attendeesData));
      }
    } catch (_) {}
  }

  Future<void> _loadLocalAttendeesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var event in _events) {
        final cached = prefs.getString('eventmatch_attendees_${event.id}');
        if (cached != null && cached.isNotEmpty) {
          final decoded = jsonDecode(cached) as List;
          for (var item in decoded) {
            final uId = item['id']?.toString();
            if (uId == null || uId.isEmpty) continue;
            if (!event.attendees.any((u) => u.id.toLowerCase().trim() == uId.toLowerCase().trim())) {
              event.attendees.add(UserModel(
                id: uId,
                name: item['name']?.toString() ?? 'Katılımcı',
                avatarUrl: item['avatarUrl']?.toString() ?? '',
                city: item['city']?.toString(),
              ));
            }
          }
        }
      }
    } catch (_) {}
  }

  void _subscribeToAttendeesBroadcast() {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    try {
      _attendeesSyncChannel?.unsubscribe();
      _attendeesSyncChannel = _supabase.channel('event_attendees_sync');
      _attendeesSyncChannel?.onBroadcast(
        event: 'attendee_change',
        callback: (payload) {
          _handleBroadcastAttendeeChange(payload);
        },
      ).subscribe((status, [error]) {
        debugPrint('📡 [BROADCAST] Event attendees broadcast sync durumu: $status');
      });
    } catch (e) {
      debugPrint('[EventService] Broadcast attendees sync hatası: $e');
    }
  }

  void _broadcastAttendeeChange({
    required String eventId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String? userCity,
    required String status,
  }) {
    try {
      _attendeesSyncChannel?.sendBroadcastMessage(
        event: 'attendee_change',
        payload: {
          'event_id': eventId,
          'user_id': userId,
          'user_name': userName,
          'user_avatar': userAvatar,
          'user_city': userCity,
          'status': status,
        },
      );
    } catch (_) {}
  }

  void _handleBroadcastAttendeeChange(Map<String, dynamic> payload) {
    try {
      final eventId = payload['event_id']?.toString();
      final rawUserId = payload['user_id']?.toString();
      final status = payload['status']?.toString();
      if (eventId == null || rawUserId == null) return;

      final lowerUserId = rawUserId.toLowerCase().trim();
      final myUid = currentUserId.toLowerCase().trim();
      if (lowerUserId == myUid) {
        return;
      }

      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex < 0) return;

      if (status == 'cancelled') {
        _events[eventIndex].attendees.removeWhere((u) => u.id.toLowerCase().trim() == lowerUserId);
        _saveEventAttendeesLocally(eventId);
        notifyListeners();
      } else if (status == 'joined') {
        if (!_events[eventIndex].attendees.any((u) => u.id.toLowerCase().trim() == lowerUserId)) {
          final attendee = UserModel(
            id: rawUserId,
            name: payload['user_name']?.toString() ?? 'Katılımcı',
            avatarUrl: payload['user_avatar']?.toString() ?? '',
            city: payload['user_city']?.toString(),
          );
          _events[eventIndex].attendees.add(attendee);
          _saveEventAttendeesLocally(eventId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[EventService] Broadcast attendee error: $e');
    }
  }

  void _subscribeToAttendeesRealtime() {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }
    try {
      _attendeesChannel?.unsubscribe();
      _attendeesChannel = _supabase
          .channel('public_event_attendees_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'event_attendees',
            callback: (payload) {
              _handleAttendeesChangeEvent(payload);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 [SUPABASE REALTIME] Event Attendees CDC akışı durumu: $status');
          });
    } catch (e) {
      debugPrint('[EventService] Realtime attendees hatası: $e');
    }
  }

  void _handleAttendeesChangeEvent(PostgresChangePayload payload) async {
    try {
      final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (record.isEmpty) return;
      final eventId = record['event_id']?.toString();
      final rawUserId = record['user_id']?.toString();
      final status = record['status']?.toString();

      if (eventId == null || rawUserId == null) return;
      final lowerUserId = rawUserId.toLowerCase().trim();
      final myUid = currentUserId.toLowerCase().trim();

      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex < 0) return;

      if (payload.eventType == PostgresChangeEvent.delete || status == 'cancelled') {
        _events[eventIndex].attendees.removeWhere((u) => u.id.toLowerCase() == lowerUserId);
        if (lowerUserId == myUid) {
          currentUser.plannedEvents.remove(eventId);
          _savePlannedEvents();
        }
        _saveEventAttendeesLocally(eventId);
        notifyListeners();
      } else if (status == 'joined') {
        if (!_events[eventIndex].attendees.any((u) => u.id.toLowerCase() == lowerUserId)) {
          UserModel attendee = UserModel(id: rawUserId, name: 'Katılımcı', avatarUrl: '');
          if (lowerUserId == myUid) {
            attendee = UserModel(id: currentUserId, name: currentUser.name, avatarUrl: currentUser.avatarUrl);
            if (!currentUser.plannedEvents.contains(eventId)) {
              currentUser.plannedEvents.add(eventId);
              _savePlannedEvents();
            }
          } else {
            try {
              final uRes = await _supabase.from('users').select('name, gender').eq('id', rawUserId).maybeSingle();
              String attendeeAvatar = '';
              try {
                final pRes = await _supabase.from('user_photos').select('storage_url').eq('user_id', rawUserId).eq('is_active', true).order('sort_order', ascending: true).limit(1).maybeSingle();
                if (pRes != null && pRes['storage_url'] != null) {
                  final rawUrl = pRes['storage_url'].toString();
                  if (UserModel.isValidPhotoUrl(rawUrl)) {
                    attendeeAvatar = rawUrl;
                  }
                }
              } catch (_) {}
              if (uRes != null) {
                attendee = UserModel(
                  id: rawUserId,
                  name: uRes['name'] ?? 'Katılımcı',
                  gender: uRes['gender']?.toString(),
                  avatarUrl: attendeeAvatar,
                );
              }
            } catch (_) {}
          }
          _events[eventIndex].attendees.add(attendee);
          _saveEventAttendeesLocally(eventId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[EventService] Attendees change handling error: $e');
    }
  }

  void _populateFallbackEvents() {
    final now = DateTime.now();
    final mockList = [
      EventModel(
        id: 'biletix_aleyna_tilki_live',
        title: 'Aleyna Tilki Konseri',
        category: 'Konser',
        location: 'Harbiye Cemil Topuzlu Açıkhava Tiyatrosu, İstanbul',
        dateTime: DateTime(now.year, now.month, now.day, 23, 59),
        description: 'Aleyna Tilki en sevilen hit şarkıları, büyüleyici dans şovu ve dev orkestrasıyla bu akşam Harbiye Açıkhava sahnesinde dinleyicileriyle buluşuyor!',
        imageUrl: 'https://cdn-images.dzcdn.net/images/artist/aa451cd32910ea3553ebaa714b7e8e9c/1000x1000-000000-80-0-0.jpg',
        latitude: 41.0468,
        longitude: 28.9882,
        ticketUrl: 'https://www.biletix.com/performance/ALEYNA/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🔥 Canlı Pop Şov',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_sila_akustik_live',
        title: 'Sıla - KerkiSolfej Akustik Konseri',
        category: 'Konser',
        location: 'Maximum UNIQ Açıkhava, İstanbul',
        dateTime: DateTime(now.year, now.month, now.day, 23, 59),
        description: 'Türk popunun güçlü sesi Sıla, KerkiSolfej organizasyonuyla bu akşam Maximum UNIQ Açıkhava sahnesinde unutulmaz bir akustik gece sunuyor!',
        imageUrl: 'https://image-cdn-fa.spotifycdn.com/image/ab6761610000e5ebc6b5e030f9a843e7338bc5f1',
        latitude: 41.1114,
        longitude: 29.0233,
        ticketUrl: 'https://www.biletix.com/performance/SILA/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '✨ Unutulmaz Akustik',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z1HyzZyMZk2Qaely',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'Maximum UNIQ Açıkhava, İstanbul',
        dateTime: now.add(const Duration(days: 3, hours: 21)),
        description: 'Grammy ödüllü rock devi The Black Keys, dünya turnesi kapsamında İstanbul sahnesinde canlı performansıyla dinleyicilerle buluşuyor!',
        imageUrl: 'https://s1.ticketm.net/dam/a/1a5/c5f563b8-baf5-4342-97e6-b4a9147c51a5_SOURCE',
        latitude: 41.1114,
        longitude: 29.0233,
        ticketUrl: 'https://www.biletix.com/performance/BLACKKEYS/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🔥 Efsane Rock',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z1HyzZyMZkQjaGjy',
        title: 'The Sisters of Mercy',
        category: 'Konser',
        location: 'Paribu Art - Ana Sahne, İstanbul',
        dateTime: now.add(const Duration(days: 5, hours: 21)),
        description: 'Post-punk ve gotik rock efsanesi The Sisters of Mercy, unutulmaz hitleri ve büyüleyici sahne ışıklarıyla İstanbul\'da sahnede.',
        imageUrl: 'https://s1.ticketm.net/dam/a/b8b/f33dd002-8a40-49f5-a9cd-9e1e4edd1b8b_SOURCE',
        latitude: 40.9914,
        longitude: 29.0364,
        ticketUrl: 'https://www.biletix.com/performance/5PR51/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '✨ Kült Gece',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z2HyzZyMZkQ_qqvve',
        title: 'Saint Levant - Afandi World Tour',
        category: 'Konser',
        location: 'Zorlu PSM - Turkcell Sahnesi, İstanbul',
        dateTime: now.add(const Duration(days: 7, hours: 20)),
        description: 'Global müzik sahnesinin yükselen yıldızı Saint Levant, Afandi World Tour turnesiyle İstanbul Zorlu PSM\'de sevenleriyle buluşuyor.',
        imageUrl: 'https://s1.ticketm.net/dam/a/130/06ba4e22-a1ba-4046-b822-f55c0e34f130_SOURCE',
        latitude: 41.0664,
        longitude: 29.0172,
        ticketUrl: 'https://www.biletix.com/performance/SAINTLEVANT/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🔥 Dünya Turnesi',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z1HyzZyMZkxva60_',
        title: 'Black Veil Brides',
        category: 'Konser',
        location: 'KüçükÇiftlik Park, İstanbul',
        dateTime: now.add(const Duration(days: 9, hours: 20)),
        description: 'Hard rock ve glam metal grubu Black Veil Brides, enerjik ve dinamik sahne şovuyla İstanbul KüçükÇiftlik Park sahnesinde.',
        imageUrl: 'https://s1.ticketm.net/dam/a/f7d/82a26e44-b08e-45d4-8b4a-99afa558ff7d_SOURCE',
        latitude: 41.0422,
        longitude: 28.9897,
        ticketUrl: 'https://www.biletix.com/performance/BVB/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '⚡ Metal Coşkusu',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z2HyzZyMZkQ_qQvve',
        title: 'Snarky Puppy',
        category: 'Konser',
        location: 'Harbiye Cemil Topuzlu Açıkhava Tiyatrosu, İstanbul',
        dateTime: now.add(const Duration(days: 11, hours: 21)),
        description: 'Grammy ödüllü caz-füzyon kolektifi Snarky Puppy, muhteşem enstrümantal ziyafetiyle Harbiye Açıkhava sahnesinde.',
        imageUrl: 'https://s1.ticketm.net/dam/a/472/a218a4e5-3abf-463a-9bd6-7e59366ec472_SOURCE',
        latitude: 41.0468,
        longitude: 28.9882,
        ticketUrl: 'https://www.biletix.com/performance/SNARKY/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎷 Caz & Füzyon',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z1HyzZyMZ62Qk7vve',
        title: 'Black Label Society',
        category: 'Konser',
        location: 'Dorock XL Kadıköy, İstanbul',
        dateTime: now.add(const Duration(days: 13, hours: 21, minutes: 30)),
        description: 'Zakk Wylde önderliğindeki efsanevi heavy metal grubu Black Label Society canlı ve sert riffleriyle sahnede.',
        imageUrl: 'https://s1.ticketm.net/dam/a/197/5f1295dd-f818-41ce-83b4-50db41750197_SOURCE',
        latitude: 40.9902,
        longitude: 29.0289,
        ticketUrl: 'https://www.biletix.com/performance/BLS/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎸 Ağır Metal',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z1HyzZyMZkK3aCt-',
        title: 'Mavi Teneffüs Konseri',
        category: 'Konser',
        location: 'Bostancı Gösteri Merkezi, İstanbul',
        dateTime: now.add(const Duration(days: 15, hours: 21)),
        description: 'Mavi en sevilen şarkıları ve özel akustik repertuvarıyla Bostancı Gösteri Merkezi sahnesinde.',
        imageUrl: 'https://s1.ticketm.net/dam/a/f7c/8603c0fb-e2f9-4bb2-b1cf-54a66a3f8f7c_SOURCE',
        latitude: 40.9634,
        longitude: 29.0945,
        ticketUrl: 'https://www.biletix.com/performance/MAVI/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '💖 Canlı Akustik',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z2HyzZyMZkQ_3kvve',
        title: 'Bilal - Celebrating 25 Years',
        category: 'Konser',
        location: 'Babylon Bomonti, İstanbul',
        dateTime: now.add(const Duration(days: 17, hours: 21, minutes: 30)),
        description: 'Neo-soul ve R&B ikonu Bilal, efsanevi 1st Born Second albümünün 25. yıl dönümü turnesiyle Babylon sahnesinde.',
        imageUrl: 'https://s1.ticketm.net/dam/a/a44/5664b090-6e0f-4987-856f-ff1ca406aa44_SOURCE',
        latitude: 41.0582,
        longitude: 28.9803,
        ticketUrl: 'https://www.biletix.com/performance/BILAL/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎤 Neo-Soul',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z6HyzZyMZGkvQSHZv',
        title: 'Arturo Sandoval Canlı',
        category: 'Konser',
        location: 'Zorlu PSM - Turkcell Platinum Sahnesi, İstanbul',
        dateTime: now.add(const Duration(days: 19, hours: 20, minutes: 30)),
        description: '10 Grammy ve Emmy ödüllü caz efsanesi Arturo Sandoval, Latin caz fırtınası estirmek üzere Zorlu PSM\'de!',
        imageUrl: 'https://s1.ticketm.net/dam/a/ce9/02bef084-80d2-4392-be0b-de92e8d52ce9_SOURCE',
        latitude: 41.0664,
        longitude: 29.0172,
        ticketUrl: 'https://www.biletix.com/performance/ARTURO/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎺 Efsane Caz',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_Z2HyzZyMZk54bvvve',
        title: 'Swallow The Sun - Ocean Of Grief',
        category: 'Konser',
        location: 'IF Performance Hall Beşiktaş, İstanbul',
        dateTime: now.add(const Duration(days: 21, hours: 20)),
        description: 'Kuzeyin melankolik doom metal devleri Swallow The Sun, Ocean Of Grief ile birlikte IF Beşiktaş sahnesinde.',
        imageUrl: 'https://s1.ticketm.net/dam/a/737/d0a621e9-d41e-46c0-bd8d-9589c46ac737_SOURCE',
        latitude: 41.0428,
        longitude: 29.0069,
        ticketUrl: 'https://www.biletix.com/performance/SWALLOW/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '⚡ Doom Metal',
        isPopular: true,
      ),
      // --- STAND-UP / KOMEDİ ETKİNLİKLERİ ---
      EventModel(
        id: 'biletix_standup_baturay',
        title: 'Baturay Özdemir Stand-up Gösterisi',
        category: 'Stand-up',
        location: 'Bostancı Gösteri Merkezi, İstanbul',
        dateTime: now.add(const Duration(days: 2, hours: 20, minutes: 30)),
        description: 'Baturay Özdemir kapalı gişe sahnelediği yepyeni stand-up gösterisiyle Bostancı Gösteri Merkezi\'nde!',
        imageUrl: 'https://images.bursadabugun.com/editor/haber/18022023/baturay-ozdemir-stand-up-gosterisi-ile-bursada-63f08fe717e13.jpg',
        latitude: 40.9634,
        longitude: 29.0945,
        ticketUrl: 'https://www.biletix.com/performance/BATURAY/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '😂 Kahkaha Dolu Stand-up',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_standup_dogu_demirkol',
        title: 'Doğu Demirkol - Stand Up',
        category: 'Stand-up',
        location: 'Zorlu PSM - Turkcell Sahnesi, İstanbul',
        dateTime: now.add(const Duration(days: 4, hours: 21)),
        description: 'Doğu Demirkol, kendine has mizahı ve günlük hayat gözlemlerinden derlediği stand-up gösterisiyle Zorlu PSM\'de sahnede.',
        imageUrl: 'https://images.unsplash.com/photo-1514306191717-452ec28c7814?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.0664,
        longitude: 29.0172,
        ticketUrl: 'https://www.biletix.com/performance/DOGU/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎤 Stand-up Komedi',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_standup_kaan_sekban',
        title: 'Kaan Sekban - Saçmalar',
        category: 'Stand-up',
        location: 'Caddebostan Kültür Merkezi, İstanbul',
        dateTime: now.add(const Duration(days: 6, hours: 20, minutes: 30)),
        description: 'Plaza hayatından sahnelere uzanan samimi hikayesiyle Kaan Sekban, kahkaha dolu tek kişilik gösterisi Saçmalar ile sahnede.',
        imageUrl: 'https://images.unsplash.com/photo-1585699324551-f6c309eedeca?auto=format&fit=crop&q=80&w=1200',
        latitude: 40.9682,
        longitude: 29.0583,
        ticketUrl: 'https://www.biletix.com/performance/KAAN/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎭 Tek Kişilik Şov',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_standup_tuzbiber',
        title: 'TuzBiber 6\'lı Stand Up Gecesi',
        category: 'Stand-up',
        location: 'Kadıköy Boa Sahne, İstanbul',
        dateTime: now.add(const Duration(days: 8, hours: 21)),
        description: 'Türkiye\'nin en sevilen bağımsız stand-up kolektifi TuzBiber, 6 farklı komedyenin peş peşe performansıyla Kadıköy Boa Sahne\'de.',
        imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&q=80&w=1200',
        latitude: 40.9892,
        longitude: 29.0275,
        ticketUrl: 'https://www.biletix.com/performance/TUZBIBER/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🔥 Stand-up Kulübü',
        isPopular: true,
      ),

      // --- FESTİVAL ETKİNLİKLERİ ---
      EventModel(
        id: 'biletix_fest_istanbul_caz',
        title: 'İstanbul Caz Festivali - Harbiye Geceleri',
        category: 'Festival',
        location: 'Harbiye Cemil Topuzlu Açıkhava Tiyatrosu, İstanbul',
        dateTime: now.add(const Duration(days: 10, hours: 19, minutes: 30)),
        description: 'Dünya caz sahnesinin dev isimleri ve yerli virtüözlerin buluştuğu İstanbul Caz Festivali, Harbiye\'nin büyüleyici atmosferinde müzikseverlerle buluşuyor.',
        imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.0468,
        longitude: 28.9882,
        ticketUrl: 'https://www.biletix.com/performance/JAZZFEST/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎷 Uluslararası Festival',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_fest_chill_out',
        title: 'Chill-Out Festival Istanbul',
        category: 'Festival',
        location: 'Kemer Country Club, İstanbul',
        dateTime: now.add(const Duration(days: 12, hours: 12, minutes: 0)),
        description: 'Yemyeşil doğa içinde kaliteli müzik, lezzetli atölyeler ve açık hava aktiviteleriyle Chill-Out Festival unutulmaz bir hafta sonu vadediyor.',
        imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.1833,
        longitude: 28.9333,
        ticketUrl: 'https://www.biletix.com/performance/CHILLOUT/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🌿 Doğa & Müzik Festivali',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_fest_gezgin_salon',
        title: 'Gezgin Salon Festivali',
        category: 'Festival',
        location: 'Bonus Parkorman, İstanbul',
        dateTime: now.add(const Duration(days: 14, hours: 14, minutes: 0)),
        description: 'İKSV organizasyonuyla Parkorman\'da indie, alternatif rock ve elektronik müziğin dünyaca ünlü yıldızlarıyla iki günlük festival coşkusu.',
        imageUrl: 'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.1215,
        longitude: 29.0278,
        ticketUrl: 'https://www.biletix.com/performance/GEZGIN/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎪 Açıkhava Festivali',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_fest_coffee',
        title: 'Istanbul Coffee Festival',
        category: 'Festival',
        location: 'Haliç Kongre Merkezi, İstanbul',
        dateTime: now.add(const Duration(days: 16, hours: 11, minutes: 0)),
        description: 'Nitelikli kahveler, usta baristaların şovları, konserler ve atölyelerle Avrupa\'nın en büyük kahve festivali Haliç kıyısında.',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.0441,
        longitude: 28.9419,
        ticketUrl: 'https://www.biletix.com/performance/COFFEEFEST/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '☕ Şehir Festivali',
        isPopular: true,
      ),

      // --- TİYATRO ETKİNLİKLERİ ---
      EventModel(
        id: 'biletix_theatre_amadeus',
        title: 'Amadeus Tiyatro Oyunu',
        category: 'Tiyatro',
        location: 'Zorlu PSM - Turkcell Sahnesi, İstanbul',
        dateTime: now.add(const Duration(days: 18, hours: 20, minutes: 30)),
        description: 'Selçuk Yöntem ve Okan Bayülgen\'in başrollerini paylaştığı, 35 kişilik dev oyuncu ve koro kadrosuyla kapalı gişe oynayan tiyatro şaheseri.',
        imageUrl: 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.0664,
        longitude: 29.0172,
        ticketUrl: 'https://www.biletix.com/performance/AMADEUS/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🎭 Başyapıt Sahne',
        isPopular: true,
      ),
      EventModel(
        id: 'biletix_theatre_zengin_mutfagi',
        title: 'Zengin Mutfağı - Şener Şen',
        category: 'Tiyatro',
        location: 'Maximum UNIQ Açıkhava, İstanbul',
        dateTime: now.add(const Duration(days: 20, hours: 21)),
        description: 'Türk sinema ve tiyatrosunun efsanesi Şener Şen, Vasıf Öngören\'in ölümsüz eseri Zengin Mutfağı ile sahnede devleşiyor.',
        imageUrl: 'https://images.unsplash.com/photo-1469488865564-c2de10f69f96?auto=format&fit=crop&q=80&w=1200',
        latitude: 41.1114,
        longitude: 29.0233,
        ticketUrl: 'https://www.biletix.com/performance/ZENGIN/001/TURKIYE/tr',
        ticketProvider: 'Biletix',
        atmosphere: '🌟 Efsane Tiyatro',
        isPopular: true,
      ),
    ];

    for (var m in mockList) {
      if (!_events.any((e) => e.id == m.id || e.title.toLowerCase() == m.title.toLowerCase())) {
        _events.add(m);
      }
    }
  }

  Future<void> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    final authUser = _supabase.auth.currentUser;
    final userId = authUser?.id ?? currentUserId;
    currentUser.id = userId;

    // Reset to clean slate first
    currentUser.username = null;
    currentUser.city = null;
    currentUser.gender = null;
    currentUser.aboutMe = null;
    currentUser.birthDate = null;
    currentUser.tags = [];
    currentUser.socialLinks = [];
    currentUser.avatarUrl = '';
    currentUser.avatarUrls = [];
    
    // Önce yerel önbellekteki planlanan etkinlikleri ve check-in durumunu yükle
    final savedPlanned = prefs.getStringList('${userId}_userPlannedEvents') ?? [];
    for (var p in savedPlanned) {
      if (!currentUser.plannedEvents.contains(p)) {
        currentUser.plannedEvents.add(p);
      }
    }
    currentUser.checkedInEventId = prefs.getString('${userId}_userCheckedInEventId');
    currentUser.pastEvents = prefs.getStringList('${userId}_userPastEvents') ?? [];

    if (_isValidUuid(userId)) {
      try {
        final userData = await _supabase.from('users').select().eq('id', userId).maybeSingle();
        if (userData != null) {
          currentUser.username = userData['username'];
          currentUser.city = userData['city'];
          currentUser.gender = userData['gender'];
          currentUser.aboutMe = userData['bio'];
          if (userData['birth_date'] != null) {
            currentUser.birthDate = DateTime.tryParse(userData['birth_date']);
          }
          if (userData['interests'] != null) {
            currentUser.tags = List<String>.from(userData['interests'] as List);
          }
          currentUser.name = userData['name'] ?? authUser?.userMetadata?['name'] ?? 'Yeni Kullanıcı';
        } else {
          final userName = authUser?.userMetadata?['name'] ?? (authUser?.userMetadata?['full_name']) ?? 'Yeni Kullanıcı';
          currentUser.name = userName;
          final email = authUser?.email ?? '';
          final derivedUsername = email.contains('@') ? email.split('@')[0] : 'user_${userId.substring(0, 6)}';
          currentUser.username = derivedUsername;
          try {
            await _supabase.from('users').upsert({
              'id': userId,
              'name': userName,
              'username': derivedUsername,
              'email': email,
              'city': 'İstanbul',
            });
          } catch (e) {
            debugPrint('Auto upsert user profile error: $e');
          }
        }
        
        try {
          final photos = await _supabase.from('user_photos').select().eq('user_id', userId).eq('is_active', true).order('sort_order');
          if (photos.isNotEmpty) {
            final validUrls = photos
                .map((p) => p['storage_url']?.toString() ?? '')
                .where((u) => u.startsWith('http'))
                .toList();
            if (validUrls.isNotEmpty) {
              currentUser.avatarUrls = validUrls;
              currentUser.avatarUrl = validUrls.first;
            }
          }
        } catch (_) {}

        try {
          final links = await _supabase.from('user_social_links').select().eq('user_id', userId);
          if (links.isNotEmpty) {
            currentUser.socialLinks = links.map((l) => l['url'].toString()).toList();
          }
        } catch (_) {}

        try {
          final attendedRes = await _supabase.from('event_attendees')
              .select('event_id')
              .eq('user_id', userId)
              .eq('status', 'joined');
          
          if (attendedRes.isNotEmpty) {
            final fetchedEvents = attendedRes.map((r) => r['event_id'].toString()).toSet();
            for (var ev in fetchedEvents) {
              if (!currentUser.plannedEvents.contains(ev)) {
                currentUser.plannedEvents.add(ev);
              }
            }
            _savePlannedEvents();
          }
        } catch (_) {}

        if (currentUser.avatarUrls.isEmpty) {
          final cachedUrls = prefs.getStringList('${userId}_userAvatarUrls');
          if (cachedUrls != null && cachedUrls.isNotEmpty) {
            currentUser.avatarUrls = cachedUrls.where(UserModel.isValidPhotoUrl).toList();
            if (currentUser.avatarUrls.isNotEmpty) {
              currentUser.avatarUrl = currentUser.avatarUrls.first;
            }
          }
        }
        if (currentUser.avatarUrl.isEmpty || !UserModel.isValidPhotoUrl(currentUser.avatarUrl)) {
          final cachedSingle = prefs.getString('${userId}_userAvatarUrl');
          currentUser.avatarUrl = (cachedSingle != null && UserModel.isValidPhotoUrl(cachedSingle))
              ? cachedSingle
              : '';
          if (currentUser.avatarUrl.isNotEmpty && currentUser.avatarUrls.isEmpty) {
            currentUser.avatarUrls = [currentUser.avatarUrl];
          }
        }
        currentUser.avatarUrls = currentUser.avatarUrls.where(UserModel.isValidPhotoUrl).toList();
        if (currentUser.aboutMe == 'Konser ve festival sever 🎸' || currentUser.aboutMe == 'Festival ve konser tutkunu') {
          currentUser.aboutMe = null;
        }
        if (currentUser.aboutMe == null || currentUser.aboutMe!.isEmpty) {
          final cachedAbout = prefs.getString('${userId}_userAbout');
          if (cachedAbout != null &&
              cachedAbout != 'Konser ve festival sever 🎸' &&
              cachedAbout != 'Festival ve konser tutkunu' &&
              cachedAbout.trim().isNotEmpty) {
            currentUser.aboutMe = cachedAbout.trim();
          } else {
            currentUser.aboutMe = null;
          }
        }
        if (currentUser.city == null || currentUser.city!.isEmpty) {
          currentUser.city = prefs.getString('${userId}_userCity') ?? 'İstanbul';
        }
      } catch (e) {
        debugPrint('Supabase profile load error: $e');
      }
    } else {
      currentUser.name = prefs.getString('${userId}_userName') ?? 'Ali Rıza';
      currentUser.username = prefs.getString('${userId}_userUsername') ?? 'aliriza';
      
      final birthDateStr = prefs.getString('${userId}_userBirthDate');
      currentUser.birthDate = birthDateStr != null ? DateTime.tryParse(birthDateStr) : DateTime(1998, 1, 1);

      currentUser.city = prefs.getString('${userId}_userCity') ?? 'İstanbul';
      currentUser.gender = prefs.getString('${userId}_userGender') ?? 'Erkek';
      final cachedAbout = prefs.getString('${userId}_userAbout');
      if (cachedAbout != null &&
          cachedAbout != 'Konser ve festival sever 🎸' &&
          cachedAbout != 'Festival ve konser tutkunu' &&
          cachedAbout.trim().isNotEmpty) {
        currentUser.aboutMe = cachedAbout.trim();
      } else {
        currentUser.aboutMe = null;
      }
      final cachedAvatar = prefs.getString('${userId}_userAvatarUrl');
      currentUser.avatarUrl = (cachedAvatar != null && cachedAvatar.startsWith('http')) ? cachedAvatar : '';
      final cachedAvatars = prefs.getStringList('${userId}_userAvatarUrls');
      currentUser.avatarUrls = (cachedAvatars != null && cachedAvatars.isNotEmpty)
          ? cachedAvatars.where((u) => u.startsWith('http')).toList()
          : (currentUser.avatarUrl.isNotEmpty ? [currentUser.avatarUrl] : []);
      currentUser.tags = prefs.getStringList('${userId}_userTags') ?? ['Konser', 'Müzik', 'Tiyatro'];
      currentUser.socialLinks = prefs.getStringList('${userId}_userSocialLinks') ?? [];
      final localPlanned = prefs.getStringList('${userId}_userPlannedEvents');
      if (localPlanned != null) {
        for (var p in localPlanned) {
          if (!currentUser.plannedEvents.contains(p)) {
            currentUser.plannedEvents.add(p);
          }
        }
      }
      currentUser.pastEvents = prefs.getStringList('${userId}_userPastEvents') ?? ['2', '3'];
    }

    currentUser.isPrivateProfile = false;
    currentUser.hideEvents = prefs.getBool('${userId}_privacy_hide_events') ??
                             prefs.getBool('${currentUser.name}_privacy_hide_events') ??
                             prefs.getBool('privacy_hide_events') ?? false;
    currentUser.enableLocationSharing = prefs.getBool('${userId}_privacy_location_sharing') ??
                                         prefs.getBool('${currentUser.name}_privacy_location_sharing') ??
                                         prefs.getBool('privacy_location_sharing') ?? true;
    currentUser.isVerified = prefs.getBool('${userId}_is_verified') ??
                             prefs.getBool('${currentUser.name}_is_verified') ??
                             prefs.getBool('user_email_verified') ?? false;

    _syncPlannedEventsWithAttendees();
    notifyListeners();
  }

  Future<void> verifyCurrentUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUser.id;
    currentUser.isVerified = true;
    if (!currentUser.badges.contains('verified')) {
      currentUser.badges.add('verified');
    }
    await prefs.setBool('${userId}_is_verified', true);
    await prefs.setBool('${currentUser.name}_is_verified', true);
    await prefs.setBool('user_email_verified', true);
    await prefs.setString('${userId}_verified_email', email);

    try {
      final sbUser = _supabase.auth.currentUser;
      if (sbUser != null) {
        await _supabase.from('users').update({
          'is_verified': true,
        }).eq('id', sbUser.id);
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<bool> isUsernameTaken(String username, {String? excludeUserId}) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return false;
    try {
      var query = _supabase.from('users').select('id').ilike('username', clean);
      if (excludeUserId != null && excludeUserId.isNotEmpty) {
        query = query.neq('id', excludeUserId);
      }
      final res = await query.maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('isUsernameTaken error: $e');
      return false;
    }
  }

  Future<void> updatePrivacySettings({
    bool? privateProfile,
    bool? hideEvents,
    bool? locationSharing,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    currentUser.isPrivateProfile = false;
    if (hideEvents != null) {
      currentUser.hideEvents = hideEvents;
      await prefs.setBool('privacy_hide_events', hideEvents);
    }
    if (locationSharing != null) {
      currentUser.enableLocationSharing = locationSharing;
      await prefs.setBool('privacy_location_sharing', locationSharing);
    }
    notifyListeners();
  }

  void _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUser.id;

    prefs.setString('${userId}_userName', currentUser.name);
    if (currentUser.username != null) prefs.setString('${userId}_userUsername', currentUser.username!);
    if (currentUser.city != null) prefs.setString('${userId}_userCity', currentUser.city!);
    if (currentUser.gender != null) prefs.setString('${userId}_userGender', currentUser.gender!);
    if (currentUser.aboutMe != null && currentUser.aboutMe!.trim().isNotEmpty) {
      prefs.setString('${userId}_userAbout', currentUser.aboutMe!.trim());
    } else {
      prefs.remove('${userId}_userAbout');
    }
    if (currentUser.birthDate != null) prefs.setString('${userId}_userBirthDate', currentUser.birthDate!.toIso8601String());
    
    prefs.setString('${userId}_userAvatarUrl', currentUser.avatarUrl);
    prefs.setStringList('${userId}_userAvatarUrls', currentUser.avatarUrls);
    prefs.setStringList('${userId}_userTags', currentUser.tags);
    prefs.setStringList('${userId}_userSocialLinks', currentUser.socialLinks);
    prefs.setStringList('${userId}_userPlannedEvents', currentUser.plannedEvents);
    prefs.setStringList('${userId}_userPastEvents', currentUser.pastEvents);
  }

  Future<void> _savePlannedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUserId;
    await prefs.setStringList('${userId}_userPlannedEvents', currentUser.plannedEvents);
  }

  UserModel currentUser = UserModel(
    id: 'user_1',
    name: 'Ali Rıza',
    avatarUrl: '',
    avatarUrls: const [],
    aboutMe: null,
    city: 'İstanbul',
    gender: 'Erkek',
    birthDate: DateTime(1998, 1, 1),
    tags: ['Konser', 'Müzik', 'Tiyatro'],
    plannedEvents: ['1'],
    pastEvents: ['2', '3'],
  );

  Future<void> updateCurrentUser({
    required String name,
    String? username,
    String? city,
    String? gender,
    required String aboutMe,
    List<String>? socialLinks,
    required String avatarUrl,
    List<dynamic>? avatarImages,
    List<String>? tags,
    List<String>? plannedEvents,
    List<String>? pastEvents,
  }) async {
    final userId = currentUser.id;
    List<String> finalAvatarUrls = [];

    if (avatarImages != null) {
      for (var item in avatarImages) {
        if (item is String) {
          finalAvatarUrls.add(item);
        } else if (item is XFile) {
          finalAvatarUrls.add(item.path);
        }
      }
    }

    final cleanBio = aboutMe.trim().isNotEmpty ? aboutMe.trim() : null;

    if (userId != 'user_1') {
      try {
        try {
          await _supabase.from('users').update({
            'name': name,
            'username': username,
            'city': city,
            'gender': gender,
            'bio': cleanBio,
            if (tags != null) 'interests': tags,
          }).eq('id', userId);
        } catch (e) {
          await _supabase.from('users').update({
            'username': username,
            'city': city,
            'gender': gender,
            'bio': cleanBio,
            if (tags != null) 'interests': tags,
          }).eq('id', userId);
        }

        await _supabase.auth.updateUser(UserAttributes(
          data: {'name': name, 'username': username},
        ));

        if (socialLinks != null) {
          await _supabase.from('user_social_links').delete().eq('user_id', userId);
          if (socialLinks.isNotEmpty) {
            final linksData = socialLinks.map((link) => {
              'user_id': userId,
              'url': link
            }).toList();
            await _supabase.from('user_social_links').insert(linksData);
          }
        }

        if (avatarImages != null) {
          finalAvatarUrls.clear();
          int photoIndex = 0;
          for (var item in avatarImages) {
            if (item is String) {
              if (item.startsWith('http')) {
                finalAvatarUrls.add(item);
              } else if (item.isNotEmpty && !item.startsWith('assets/')) {
                try {
                  final file = File(item);
                  if (await file.exists()) {
                    final bytes = await file.readAsBytes();
                    final ext = item.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
                    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                    final pathInBucket = '${userId}/foto_${DateTime.now().millisecondsSinceEpoch}_$photoIndex.$ext';
                    await _supabase.storage.from('avatars').uploadBinary(
                      pathInBucket,
                      bytes,
                      fileOptions: FileOptions(
                        cacheControl: '3600',
                        upsert: true,
                        contentType: mime,
                      ),
                    );
                    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(pathInBucket);
                    finalAvatarUrls.add(publicUrl);
                  }
                } catch (e) {
                  debugPrint('[Storage] Local file upload to avatars failed: $e');
                }
              }
            } else if (item is XFile) {
              try {
                final bytes = await item.readAsBytes();
                final ext = item.name.toLowerCase().endsWith('.png') || item.mimeType == 'image/png' ? 'png' : 'jpg';
                final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                final pathInBucket = '${userId}/foto_${DateTime.now().millisecondsSinceEpoch}_$photoIndex.$ext';
                await _supabase.storage.from('avatars').uploadBinary(
                  pathInBucket,
                  bytes,
                  fileOptions: FileOptions(
                    cacheControl: '3600',
                    upsert: true,
                    contentType: mime,
                  ),
                );
                final publicUrl = _supabase.storage.from('avatars').getPublicUrl(pathInBucket);
                finalAvatarUrls.add(publicUrl);
              } catch (e) {
                debugPrint('[Storage] XFile upload to avatars failed: $e');
              }
            }
            photoIndex++;
          }
          
          final validHttpUrls = finalAvatarUrls.where((u) => u.startsWith('http')).toList();
          if (validHttpUrls.isNotEmpty) {
            await _supabase.from('user_photos').delete().eq('user_id', userId);
            final photosData = validHttpUrls.asMap().entries.map((entry) => {
              'user_id': userId,
              'storage_url': entry.value,
              'sort_order': entry.key,
              'is_active': true
            }).toList();
            await _supabase.from('user_photos').insert(photosData);
          }
        }
      } catch (e) {
        throw Exception('Profil güncellenirken bir hata oluştu: $e');
      }
    }

    currentUser.name = name;
    if (username != null) currentUser.username = username;
    if (city != null) currentUser.city = city;
    if (gender != null) currentUser.gender = gender;
    currentUser.aboutMe = cleanBio;
    if (socialLinks != null) currentUser.socialLinks = socialLinks;
    
    if (avatarImages != null) {
      final validHttpUrls = finalAvatarUrls.where((u) => u.startsWith('http')).toList();
      currentUser.avatarUrls = validHttpUrls.isNotEmpty ? validHttpUrls : finalAvatarUrls;
      if (currentUser.avatarUrls.isNotEmpty) {
        currentUser.avatarUrl = currentUser.avatarUrls.first;
      } else {
        currentUser.avatarUrl = '';
      }
    }
    if (tags != null) currentUser.tags = tags;
    if (plannedEvents != null) currentUser.plannedEvents = plannedEvents;
    if (pastEvents != null) currentUser.pastEvents = pastEvents;
    _saveProfileData();
    notifyListeners();
  }

  Future<void> deleteUploadedPhoto(String url) async {
    final userId = currentUser.id;
    if (userId != 'user_1') {
      try {
        await _supabase.from('user_photos').delete().eq('storage_url', url).eq('user_id', userId);
        
        String? storagePath;
        final bucketKeyword = '/avatars/';
        if (url.contains(bucketKeyword)) {
          final index = url.indexOf(bucketKeyword);
          var pathPart = url.substring(index + bucketKeyword.length);
          if (pathPart.contains('?')) {
            pathPart = pathPart.split('?').first;
          }
          storagePath = Uri.decodeComponent(pathPart);
        }
        
        if (storagePath != null) {
          await _supabase.storage.from('avatars').remove([storagePath]);
        }
      } catch (e) {
        throw Exception('Fotoğraf silinirken hata oluştu: $e');
      }
    }
    
    currentUser.avatarUrls.remove(url);
    if (currentUser.avatarUrl == url) {
      currentUser.avatarUrl = currentUser.avatarUrls.isNotEmpty ? currentUser.avatarUrls.first : '';
    }
    _saveProfileData();
    notifyListeners();
  }

  final List<String> activityFeed = [];

  List<String> categories = ['Tümü', 'Konser', 'Tiyatro', 'Stand-up', 'Festival'];
  static const List<String> sportsSubFilters = <String>[];

  List<String> cities = ['Tüm Şehirler', 'İstanbul', 'Ankara', 'İzmir', 'Antalya', 'Bursa', 'Adana', 'Gaziantep', 'Mersin'];
  
  static const List<String> allTurkishCities = [
    'Tüm Şehirler', 'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
    'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın', 'Batman',
    'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale',
    'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
    'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay',
    'Iğdır', 'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman',
    'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis',
    'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla',
    'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Siirt',
    'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli',
    'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
  ];

  String _selectedCategory = 'Tümü';
  String _selectedSportsSubFilter = 'Tümü';
  String _selectedCity = 'Tüm Şehirler';
  String _searchQuery = '';

  final List<String> dateFilters = ['Tümü', 'Bugün', 'Bu Hafta', 'Bu Ay'];
  String _selectedDateFilter = 'Tümü';
  String get selectedDateFilter => _selectedDateFilter;

  void setDateFilter(String filter) {
    _selectedDateFilter = filter;
    notifyListeners();
  }

  List<String> _featuredCarouselEventIds = [];
  List<String> get featuredCarouselEventIds => [..._featuredCarouselEventIds];

  Future<void> _loadCarouselSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _featuredCarouselEventIds = prefs.getStringList('featured_carousel_event_ids') ?? [];
    } catch (_) {}
  }

  Future<void> saveCarouselSettings(List<String> eventIds) async {
    _featuredCarouselEventIds = eventIds;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('featured_carousel_event_ids', _featuredCarouselEventIds);
    } catch (_) {}
  }

  void toggleCarouselFeatured(String eventId) {
    if (_featuredCarouselEventIds.contains(eventId)) {
      _featuredCarouselEventIds.remove(eventId);
    } else {
      _featuredCarouselEventIds.add(eventId);
    }
    notifyListeners();
    _saveCarouselIdsToPrefs();
  }

  void _saveCarouselIdsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('featured_carousel_event_ids', _featuredCarouselEventIds);
    } catch (_) {}
  }

  List<EventModel> getCarouselEvents() {
    final now = DateTime.now();
    final active = _events.where((e) => e.isValidForDisplay).toList();
    if (active.isEmpty) return [];

    // 1. Şehir ve Konum Önceliği Belirleme:
    // Kullanıcı açıkça bir il seçtiyse (Örn: 'Ankara', 'İzmir', 'İstanbul') -> Öncelik kesinlikle seçtiği ildedir.
    // Eğer il filtrelemesi kullanmazsa ('Tüm Şehirler') -> Kullanıcının konumundaki / kayıtlı olduğu ildeki (currentUser.city) etkinlikler öncelikli akar.
    final bool hasExplicitCityFilter = _selectedCity.isNotEmpty && _selectedCity != 'Tüm Şehirler';
    final String? priorityCity = hasExplicitCityFilter
        ? _selectedCity
        : (currentUser.city != null && currentUser.city!.trim().isNotEmpty ? currentUser.city : null);

    List<EventModel> prioritizedEvents = [];
    List<EventModel> otherEvents = [];

    if (priorityCity != null && priorityCity.trim().isNotEmpty) {
      final normPriority = _normalizeText(priorityCity);
      for (var ev in active) {
        final locNorm = _normalizeText(ev.location);
        if (locNorm.contains(normPriority)) {
          prioritizedEvents.add(ev);
        } else {
          otherEvents.add(ev);
        }
      }
    } else {
      prioritizedEvents = List.from(active);
    }

    // Etkinlikleri ilgi ve popülerlik puanına göre sırala
    int scoreEvent(EventModel a) {
      int score = (a.attendees.length * 6) + (a.isPopular ? 15 : 0);
      final diffDays = a.dateTime.difference(now).inDays;
      if (diffDays >= 0 && diffDays <= 7) score += 10;
      if (a.ticketUrl != null && a.ticketUrl!.isNotEmpty) score += 5;
      return score;
    }

    prioritizedEvents.sort((a, b) => scoreEvent(b).compareTo(scoreEvent(a)));
    otherEvents.sort((a, b) => scoreEvent(b).compareTo(scoreEvent(a)));

    // Eğer admin panelinden özel vitrin için sabitlenmiş etkinlikler varsa en başa al
    if (_featuredCarouselEventIds.isNotEmpty) {
      final pinnedInPriority = prioritizedEvents.where((e) => _featuredCarouselEventIds.contains(e.id)).toList();
      prioritizedEvents.removeWhere((e) => _featuredCarouselEventIds.contains(e.id));
      prioritizedEvents.insertAll(0, pinnedInPriority);
    }

    // Sonuç listesini oluştur:
    // Kullanıcı il seçtiyse öncelikle o ildeki etkinlikler akar.
    // Eğer il filtrelemesi seçilmemişse kullanıcının konumundaki etkinlikler öncelikli akar, ardından vitrin zenginliği için popüler etkinlikler akar.
    final List<EventModel> result = [];
    result.addAll(prioritizedEvents);

    if (!hasExplicitCityFilter || result.length < 3) {
      for (var ev in otherEvents) {
        if (!result.any((e) => e.id == ev.id)) {
          result.add(ev);
          if (result.length >= 8) break;
        }
      }
    }

    return result.take(8).toList();
  }

  String get selectedCategory => _selectedCategory;
  String get selectedSportsSubFilter => _selectedSportsSubFilter;
  String get selectedCity => _selectedCity;
  String get searchQuery => _searchQuery;

  List<EventModel> getAdminEvents() => _events.where((e) => !e.isSportsEvent && !e.isExpired).toList();

  void setCategory(String category) {
    _selectedCategory = category;
    _selectedSportsSubFilter = 'Tümü';
    notifyListeners();
  }

  void setSportsSubFilter(String subFilter) {
    _selectedSportsSubFilter = 'Tümü';
    notifyListeners();
  }

  void setCity(String city) {
    _selectedCity = city;
    if (!cities.contains(city)) {
      cities.insert(1, city);
    }
    notifyListeners();

    if (city != 'Tüm Şehirler' && city.trim().isNotEmpty) {
      _searchLiveEvents(city);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();

    if (query.trim().length >= 2 && query.trim().toLowerCase() != 'biletix') {
      _searchLiveEvents(query.trim());
    }
  }

  Future<void> _searchLiveEvents(String query) async {
    try {
      final liveResults = await ExternalEventService().fetchLiveTicketmasterEvents(keyword: query);
      bool addedAny = false;
      for (var live in liveResults) {
        if (!live.isValidForDisplay) continue;
        if (!_events.any((e) => e.id == live.id || e.title.toLowerCase() == live.title.toLowerCase())) {
          _events.add(live);
          addedAny = true;
        }
      }
      if (addedAny) {
        _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EventService] Live search error: $e');
    }
  }

  void addCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('spor') || lower.contains('musabaka') || lower.contains('müsabaka') || lower.contains('sport')) {
      return;
    }
    if (!categories.contains(category)) {
      categories.add(category);
      notifyListeners();
    }
  }

  void addEvent(EventModel event) {
    if (event.isSportsEvent) return;
    _events.insert(0, event);
    notifyListeners();
  }

  void updateEvent(EventModel event) {
    if (event.isSportsEvent) {
      _events.removeWhere((e) => e.id == event.id);
      notifyListeners();
      return;
    }
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      _events[index] = event;
      notifyListeners();
    }
  }

  Future<void> importEventsFromExcel(List<int> bytes) async {
    var excel = Excel.decodeBytes(bytes);
    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      for (var i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty) continue;
        try {
          final title = row[0]?.value?.toString() ?? 'İsimsiz Etkinlik';
          final category = row.length > 1 ? row[1]?.value?.toString() ?? 'Genel' : 'Genel';
          final location = row.length > 2 ? row[2]?.value?.toString() ?? 'İstanbul' : 'İstanbul';
          
          DateTime dateTime = DateTime.now().add(Duration(days: i));
          if (row.length > 3 && row[3]?.value != null) {
            final parsedDate = DateTime.tryParse(row[3]!.value.toString());
            if (parsedDate != null) dateTime = parsedDate;
          }

          final description = row.length > 4 ? row[4]?.value?.toString() ?? '' : '';
          final imageUrl = row.length > 5 ? row[5]?.value?.toString() ?? 'assets/images/placeholder.png' : 'assets/images/placeholder.png';
          
          double? lat;
          if (row.length > 6 && row[6]?.value != null) lat = double.tryParse(row[6]!.value.toString());
          
          double? lng;
          if (row.length > 7 && row[7]?.value != null) lng = double.tryParse(row[7]!.value.toString());

          final newEvent = EventModel(
            id: 'e_excel_${DateTime.now().millisecondsSinceEpoch}_$i',
            title: title,
            category: category == 'null' ? 'Diğer' : category,
            location: location == 'null' ? 'Bilinmeyen Konum' : location,
            dateTime: dateTime,
            description: description == 'null' ? '' : description,
            imageUrl: (imageUrl.isEmpty || imageUrl == 'null') ? 'assets/images/placeholder.png' : imageUrl,
            latitude: lat,
            longitude: lng,
            attendees: [],
          );
          
          _events.insert(0, newEvent);
        } catch (e) {
          debugPrint('Error parsing row $i: $e');
        }
      }
    }
    notifyListeners();
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  final List<EventModel> _events = [];
  final Map<String, String> _normalizedTextCache = {};

  String _normalizeText(String input) {
    if (input.isEmpty) return '';
    if (_normalizedTextCache.containsKey(input)) {
      return _normalizedTextCache[input]!;
    }
    final normalized = input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .replaceAll('ı', 'i')
        .toLowerCase()
        .replaceAll('i̇', 'i');
    if (_normalizedTextCache.length > 1000) {
      _normalizedTextCache.clear();
    }
    _normalizedTextCache[input] = normalized;
    return normalized;
  }

  List<EventModel> get filteredEvents {
    final now = DateTime.now();
    List<EventModel> activeEvents = _events.where((e) => e.isValidForDisplay).toList();

    // 1. Arama sorgusu varsa: Tüm şehirler ve tüm kategoriler genelinde arama yap ve doğrudan döndür!
    if (_searchQuery.trim().isNotEmpty) {
      final rawQuery = _searchQuery.trim();
      final normQuery = _normalizeText(rawQuery);
      final tokens = normQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      return activeEvents.where((e) {
        final title = _normalizeText(e.title);
        final desc = _normalizeText(e.description);
        final loc = _normalizeText(e.location);
        final cat = _normalizeText(e.category);
        final provider = _normalizeText(e.ticketProvider ?? '');
        final ticketUrl = _normalizeText(e.ticketUrl ?? '');

        if (normQuery == 'biletix' || normQuery.contains('biletix')) {
          if (e.id.startsWith('biletix_') || provider.contains('biletix') || ticketUrl.contains('biletix')) {
            return true;
          }
        }

        return tokens.every((token) {
          return title.contains(token) || 
                 desc.contains(token) || 
                 loc.contains(token) || 
                 cat.contains(token) ||
                 provider.contains(token) ||
                 ticketUrl.contains(token);
        });
      }).toList();
    }

    // 2. Arama yapılmıyorsa: Seçili Şehir filtresini uygula
    if (_selectedCity != 'Tüm Şehirler') {
      final cityNorm = _normalizeText(_selectedCity);
      activeEvents = activeEvents.where((e) => _normalizeText(e.location).contains(cityNorm)).toList();
    }

    // 3. Tarih Filtresi ('Tümü', 'Bugün', 'Bu Hafta', 'Bu Ay')
    if (_selectedDateFilter == 'Bugün') {
      activeEvents = activeEvents.where((e) {
        return e.dateTime.year == now.year &&
               e.dateTime.month == now.month &&
               e.dateTime.day == now.day;
      }).toList();
    } else if (_selectedDateFilter == 'Bu Hafta') {
      final endOfWeek = now.add(const Duration(days: 7));
      activeEvents = activeEvents.where((e) => e.dateTime.isBefore(endOfWeek)).toList();
    } else if (_selectedDateFilter == 'Bu Ay') {
      final endOfMonth = now.add(const Duration(days: 30));
      activeEvents = activeEvents.where((e) => e.dateTime.isBefore(endOfMonth)).toList();
    }
    
    if (_selectedCategory == 'Tümü') return activeEvents;
    
    if (_selectedCategory == '🔥 Popüler') {
      final sorted = List<EventModel>.from(activeEvents)..sort((a, b) {
        final scoreA = (a.attendees.length * 5) + (a.isPopular ? 10 : 0);
        final scoreB = (b.attendees.length * 5) + (b.isPopular ? 10 : 0);
        return scoreB.compareTo(scoreA);
      });
      return sorted;
    }
    
    if (_selectedCategory == '🌟 Sana Özel') {
      final userKeywords = <String>{};
      for (var t in currentUser.tags) {
        if (t.trim().isNotEmpty) userKeywords.add(_normalizeText(t.trim()));
      }
      for (var p in currentUser.pastEvents) {
        if (p.trim().isNotEmpty) userKeywords.add(_normalizeText(p.trim()));
      }
      for (var pl in currentUser.plannedEvents) {
        if (pl.trim().isNotEmpty) userKeywords.add(_normalizeText(pl.trim()));
      }
      for (var e in _events) {
        if (e.attendees.any((u) => u.id == currentUser.id)) {
          userKeywords.add(_normalizeText(e.category));
          userKeywords.add(_normalizeText(e.title));
        }
      }

      int scoreEvent(EventModel e) {
        int score = 0;
        final titleNorm = _normalizeText(e.title);
        final catNorm = _normalizeText(e.category);
        final descNorm = _normalizeText(e.description);
        final locNorm = _normalizeText(e.location);
        final userCityNorm = currentUser.city != null ? _normalizeText(currentUser.city!) : '';

        if (userCityNorm.isNotEmpty && locNorm.contains(userCityNorm)) {
          score += 5;
        }

        for (var kw in userKeywords) {
          if (kw.isEmpty) continue;
          if (catNorm.contains(kw) || kw.contains(catNorm)) score += 10;
          if (titleNorm.contains(kw) || kw.contains(titleNorm)) score += 8;
          if (descNorm.contains(kw)) score += 4;
        }
        return score;
      }

      final scoredEvents = activeEvents.map((e) => MapEntry(e, scoreEvent(e))).toList();
      scoredEvents.sort((a, b) => b.value.compareTo(a.value));
      
      final matching = scoredEvents.where((entry) => entry.value > 0).map((entry) => entry.key).toList();
      if (matching.isNotEmpty) {
        return matching;
      }
      return scoredEvents.map((e) => e.key).toList();
    }
    
    if (_selectedCategory == '💖 Eşleşme Oranı Yüksek') {
      int getMatchRateScore(EventModel e) {
        int score = e.attendees.length * 10;
        int matchableUsers = e.attendees.where((u) => u.id != currentUser.id).length;
        score += matchableUsers * 15;
        if (e.isPopular) score += 5;
        return score;
      }

      final sorted = List<EventModel>.from(activeEvents)..sort((a, b) {
        return getMatchRateScore(b).compareTo(getMatchRateScore(a));
      });
      return sorted;
    }
    
    final selectedNorm = _normalizeText(_selectedCategory);

    return activeEvents.where((e) {
      if (e.isSportsEvent) return false;

      final catNorm = _normalizeText(e.category);
      final titleNorm = _normalizeText(e.title);
      final descNorm = _normalizeText(e.description);

      if (selectedNorm == 'konser') {
        return catNorm.contains('konser') || catNorm.contains('music') || catNorm.contains('müzik') || catNorm.contains('pop') || catNorm.contains('rock') || titleNorm.contains('konser');
      }
      if (selectedNorm == 'tiyatro') {
        return catNorm.contains('tiyatro') || catNorm.contains('theatre') || catNorm.contains('art') || titleNorm.contains('tiyatro');
      }
      if (selectedNorm == 'stand-up' || selectedNorm == 'standup') {
        return catNorm.contains('stand') || catNorm.contains('komedi') || catNorm.contains('comedy') ||
               titleNorm.contains('stand') || titleNorm.contains('komedi') || titleNorm.contains('comedy') || titleNorm.contains('özdemir') || titleNorm.contains('demirkol') || titleNorm.contains('gösteri') || descNorm.contains('stand-up');
      }
      if (selectedNorm == 'festival') {
        return catNorm.contains('festival') || catNorm.contains('fest') || catNorm.contains('parti') ||
               titleNorm.contains('festival') || titleNorm.contains('fest') || descNorm.contains('festival');
      }
      return catNorm.contains(selectedNorm) || titleNorm.contains(selectedNorm);
    }).toList();
  }

  void toggleEventVisibility(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _events[index].isActive = !_events[index].isActive;
      notifyListeners();
    }
  }

  EventModel? getEventById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> joinEvent(String eventId, [EventModel? fallbackEvent]) async {
    final uid = currentUserId;
    int eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex < 0) {
      final newEv = fallbackEvent ?? EventModel(
        id: eventId,
        title: 'Etkinlik',
        category: 'Genel',
        location: 'İstanbul',
        dateTime: DateTime.now().add(const Duration(days: 7)),
        description: '',
        imageUrl: 'assets/images/placeholder.png',
        attendees: [],
      );
      _events.add(newEv);
      eventIndex = _events.length - 1;
    }

    if (eventIndex >= 0) {
      final event = _events[eventIndex];
      if (!event.attendees.any((u) => u.id.toLowerCase().trim() == uid.toLowerCase().trim())) {
        event.attendees.insert(0, UserModel(
          id: uid,
          name: currentUser.name,
          avatarUrl: currentUser.avatarUrl,
          city: currentUser.city,
          birthDate: currentUser.birthDate,
          tags: List.from(currentUser.tags),
        ));
      }
    }

    if (!currentUser.plannedEvents.contains(eventId)) {
      currentUser.plannedEvents.add(eventId);
    }
    await _savePlannedEvents();

    await _saveEventAttendeesLocally(eventId);

    // Canlı WebSocket yayını yap (tüm bağlı cihazlar/arkadaşlar anında görsün)
    _broadcastAttendeeChange(
      eventId: eventId,
      userId: uid,
      userName: currentUser.name,
      userAvatar: currentUser.avatarUrl,
      userCity: currentUser.city,
      status: 'joined',
    );

    if (_supabase.auth.currentUser != null && _isValidUuid(uid)) {
      try {
        final existing = await _supabase.from('event_attendees')
            .select('id')
            .eq('user_id', uid)
            .eq('event_id', eventId);

        if (existing.isEmpty) {
          await _supabase.from('event_attendees').insert({
            'user_id': uid,
            'event_id': eventId,
            'status': 'joined'
          });
        } else {
          await _supabase.from('event_attendees').update({
            'status': 'joined'
          }).eq('user_id', uid).eq('event_id', eventId);
        }
      } catch (e) {
        debugPrint('Supabase event_attendees kayıt hatası: $e');
      }
    }

    notifyListeners();
  }

  Future<void> leaveEvent(String eventId) async {
    final uid = currentUserId;
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex >= 0) {
      final event = _events[eventIndex];
      event.attendees.removeWhere((u) => u.id.toLowerCase().trim() == uid.toLowerCase().trim());
      await _saveEventAttendeesLocally(eventId);
    }
    currentUser.plannedEvents.remove(eventId);
    if (currentUser.checkedInEventId == eventId) {
      currentUser.checkedInEventId = null;
      _saveCheckedInEvent(null);
    }
    _savePlannedEvents();

    // Canlı WebSocket iptal yayını
    _broadcastAttendeeChange(
      eventId: eventId,
      userId: uid,
      userName: currentUser.name,
      userAvatar: currentUser.avatarUrl,
      userCity: currentUser.city,
      status: 'cancelled',
    );

    if (_supabase.auth.currentUser != null && _isValidUuid(uid)) {
      try {
        await _supabase.from('event_attendees')
            .delete()
            .eq('user_id', uid)
            .eq('event_id', eventId);
      } catch (e) {
        debugPrint('Supabase event_attendees silme hatası: $e');
      }
    }

    notifyListeners();
  }

  bool isUserAttending(String eventId) {
    if (currentUser.plannedEvents.contains(eventId)) return true;
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex >= 0) {
      final myUid = currentUserId.toLowerCase().trim();
      return _events[eventIndex].attendees.any((u) => u.id.toLowerCase().trim() == myUid);
    }
    return false;
  }

  List<EventModel> get allEvents => _events.where((e) => e.isValidForDisplay).toList();

  bool isUserCheckedIn(String eventId) {
    return currentUser.checkedInEventId == eventId;
  }

  void _saveCheckedInEvent(String? eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = currentUserId;
    if (eventId != null) {
      prefs.setString('${uid}_userCheckedInEventId', eventId);
    } else {
      prefs.remove('${uid}_userCheckedInEventId');
    }
  }

  void checkIn(String eventId) {
    currentUser.checkedInEventId = eventId;
    currentUser.points += 50;
    _saveCheckedInEvent(eventId);
    notifyListeners();
  }

  void checkOut() {
    currentUser.checkedInEventId = null;
    _saveCheckedInEvent(null);
    notifyListeners();
  }

  final Map<String, List<Map<String, dynamic>>> _venueChats = {};

  List<Map<String, dynamic>> getVenueMessages(String eventId) {
    return _venueChats[eventId] ?? [];
  }

  Future<void> _loadVenueMessagesFromStorage(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('eventmatch_venue_chat_$eventId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List;
        final list = <Map<String, dynamic>>[];
        for (var item in decoded) {
          list.add({
            'userId': item['userId'],
            'userName': item['userName'],
            'userAvatar': item['userAvatar'],
            'message': item['message'] ?? '',
            'imageUrl': item['imageUrl'],
            'audioUrl': item['audioUrl'],
            'audioDuration': item['audioDuration'],
            'time': item['time'] != null ? DateTime.tryParse(item['time'].toString()) ?? DateTime.now() : DateTime.now(),
          });
        }
        _venueChats[eventId] = list;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveVenueMessagesToStorage(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _venueChats[eventId] ?? [];
      final encoded = list.map((m) => {
        'userId': m['userId'],
        'userName': m['userName'],
        'userAvatar': m['userAvatar'],
        'message': m['message'],
        'imageUrl': m['imageUrl'],
        'audioUrl': m['audioUrl'],
        'audioDuration': m['audioDuration'],
        'time': m['time'] is DateTime ? (m['time'] as DateTime).toIso8601String() : DateTime.now().toIso8601String(),
      }).toList();
      await prefs.setString('eventmatch_venue_chat_$eventId', jsonEncode(encoded));
    } catch (_) {}
  }

  Future<void> loadVenueMessages(String eventId) async {
    _activeVenueEventId = eventId;
    await _loadVenueMessagesFromStorage(eventId);

    // Supabase messages tablosundan geçmiş mesajları çek
    try {
      final res = await _supabase
          .from('messages')
          .select('*')
          .eq('receiver_id', 'venue_$eventId')
          .order('created_at', ascending: true);

      if (res.isNotEmpty) {
        final list = <Map<String, dynamic>>[];
        final senderIds = res
            .map((m) => m['sender_id']?.toString())
            .where((id) => id != null && _isValidUuid(id))
            .cast<String>()
            .toSet()
            .toList();

        Map<String, String> senderNames = {};
        Map<String, String> senderAvatars = {};
        if (senderIds.isNotEmpty) {
          try {
            final uRes = await _supabase.from('users').select('id, name').inFilter('id', senderIds);
            for (var u in uRes) {
              senderNames[u['id'].toString().toLowerCase()] = u['name']?.toString() ?? 'Kullanıcı';
            }
          } catch (_) {}
          try {
            final pRes = await _supabase.from('user_photos').select('user_id, storage_url').inFilter('user_id', senderIds).eq('is_active', true).order('sort_order');
            for (var p in pRes) {
              final uid = p['user_id'].toString().toLowerCase();
              if (!senderAvatars.containsKey(uid) && p['storage_url'] != null) {
                senderAvatars[uid] = p['storage_url'].toString();
              }
            }
          } catch (_) {}
        }

        for (var row in res) {
          final sId = row['sender_id']?.toString() ?? '';
          final lowerSId = sId.toLowerCase();
          final isMe = lowerSId == currentUserId.toLowerCase();
          final mediaUrl = row['media_url']?.toString();
          final mediaType = row['media_type']?.toString();
          list.add({
            'userId': sId,
            'userName': isMe ? currentUser.name : (senderNames[lowerSId] ?? 'Kullanıcı'),
            'userAvatar': isMe ? currentUser.avatarUrl : (senderAvatars[lowerSId] ?? ''),
            'message': row['content']?.toString() ?? row['message']?.toString() ?? '',
            'imageUrl': mediaType == 'image' ? mediaUrl : null,
            'audioUrl': mediaType == 'audio' ? mediaUrl : null,
            'audioDuration': row['audio_duration_seconds'] != null ? int.tryParse(row['audio_duration_seconds'].toString()) : null,
            'time': row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
          });
        }
        _venueChats[eventId] = list;
        await _saveVenueMessagesToStorage(eventId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EventService] loadVenueMessages Supabase error: $e');
    }

    _subscribeToVenueChat(eventId);
  }

  void Function(String emoji)? onVenueReactionReceived;

  void _subscribeToVenueChat(String eventId) {
    try {
      _venueBroadcastChannel?.unsubscribe();
      _venueBroadcastChannel = _supabase
          .channel('venue_chat_$eventId')
          .onBroadcast(
            event: 'new_venue_message',
            callback: (payload) {
              final sId = payload['userId']?.toString() ?? '';
              final sName = payload['userName']?.toString() ?? 'Kullanıcı';
              final sAvatar = payload['userAvatar']?.toString() ?? '';
              final msg = payload['message']?.toString() ?? '';
              final imgUrl = payload['imageUrl']?.toString();
              final audUrl = payload['audioUrl']?.toString();
              final audDur = payload['audioDuration'] != null ? int.tryParse(payload['audioDuration'].toString()) : null;
              if (msg.trim().isEmpty && (imgUrl == null || imgUrl.isEmpty) && (audUrl == null || audUrl.isEmpty)) return;

              _venueChats.putIfAbsent(eventId, () => []);
              if (!_venueChats[eventId]!.any((m) => m['message'] == msg && m['userId'] == sId && m['imageUrl'] == imgUrl && m['audioUrl'] == audUrl)) {
                _venueChats[eventId]!.add({
                  'userId': sId,
                  'userName': sId.toLowerCase() == currentUserId.toLowerCase() ? currentUser.name : sName,
                  'userAvatar': sId.toLowerCase() == currentUserId.toLowerCase() ? currentUser.avatarUrl : sAvatar,
                  'message': msg,
                  'imageUrl': imgUrl,
                  'audioUrl': audUrl,
                  'audioDuration': audDur,
                  'time': DateTime.now(),
                });
                _saveVenueMessagesToStorage(eventId);
                notifyListeners();
              }
            },
          )
          .onBroadcast(
            event: 'new_venue_reaction',
            callback: (payload) {
              final emoji = payload['emoji']?.toString() ?? '❤️';
              onVenueReactionReceived?.call(emoji);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[EventService] subscribe venue chat error: $e');
    }
  }

  void sendVenueReaction(String eventId, String emoji) {
    try {
      _venueBroadcastChannel?.sendBroadcastMessage(
        event: 'new_venue_reaction',
        payload: {
          'userId': currentUserId,
          'emoji': emoji,
          'time': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  Future<String?> uploadVenueMedia(String localFilePath, {required String folder, required String extension}) async {
    try {
      final file = File(localFilePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId = currentUserId.isNotEmpty ? currentUserId : 'anonymous';
      final fileName = 'venue_$folder/${userId}_$timestamp.$extension';

      await _supabase.storage
          .from('chat-media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: extension == 'm4a' ? 'audio/mp4' : 'image/$extension',
              upsert: true,
            ),
          );

      final publicUrl = _supabase.storage.from('chat-media').getPublicUrl(fileName);
      debugPrint('[VenueStorage] ✅ Medya yüklendi: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[VenueStorage] ❌ Medya yükleme hatası: $e');
      return null;
    }
  }

  Future<void> sendVenueMessage(
    String eventId,
    String message, {
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
    String? userAvatar,
  }) async {
    final text = message.trim();
    if (text.isEmpty && (imageUrl == null || imageUrl.isEmpty) && (audioUrl == null || audioUrl.isEmpty)) return;

    final uid = currentUserId;
    final uName = currentUser.name;
    final uAvatar = (userAvatar != null && userAvatar.isNotEmpty) ? userAvatar : currentUser.avatarUrl;
    final now = DateTime.now();

    _venueChats.putIfAbsent(eventId, () => []);
    _venueChats[eventId]!.add({
      'userId': uid,
      'userName': uName,
      'userAvatar': uAvatar,
      'message': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'time': now,
    });
    await _saveVenueMessagesToStorage(eventId);
    notifyListeners();

    // 1. Canlı WebSocket yayını yap (tüm mekandakiler anında görür)
    try {
      _venueBroadcastChannel?.sendBroadcastMessage(
        event: 'new_venue_message',
        payload: {
          'userId': uid,
          'userName': uName,
          'userAvatar': uAvatar,
          'message': text,
          'imageUrl': imageUrl,
          'audioUrl': audioUrl,
          'audioDuration': audioDuration,
          'time': now.toIso8601String(),
        },
      );
    } catch (_) {}

    // 2. Supabase messages tablosuna kalıcı olarak yaz
    try {
      final mediaType = imageUrl != null ? 'image' : (audioUrl != null ? 'audio' : null);
      final mediaUrl = imageUrl ?? audioUrl;
      await _supabase.from('messages').insert({
        'sender_id': uid,
        'receiver_id': 'venue_$eventId',
        'content': text.isNotEmpty ? text : (imageUrl != null ? '📷 Fotoğraf' : '🎤 Sesli Mesaj'),
        'media_url': mediaUrl,
        'media_type': mediaType,
        'audio_duration_seconds': audioDuration,
        'created_at': now.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[EventService] sendVenueMessage persist error: $e');
    }
  }

  Map<String, dynamic> calculateVibe(UserModel targetUser) {
    int score = 0;
    List<String> commonalities = [];

    final commonTags = currentUser.tags.where((tag) => targetUser.tags.contains(tag)).toList();
    score += commonTags.length * 15;
    if (commonTags.isNotEmpty) {
      commonalities.add('İkiniz de ${commonTags.take(2).join(' ve ')} seviyorsunuz!');
    }

    final commonEvents = currentUser.plannedEvents.where((e) => targetUser.plannedEvents.contains(e)).toList();
    score += commonEvents.length * 30;
    if (commonEvents.isNotEmpty) {
      commonalities.add('Aynı etkinliğe gitmeyi planlıyorsunuz!');
    }

    if (currentUser.city != null && targetUser.city != null &&
        currentUser.city!.trim().isNotEmpty && targetUser.city!.trim().isNotEmpty &&
        currentUser.city!.trim().toLowerCase() == targetUser.city!.trim().toLowerCase()) {
      score += 10;
      commonalities.add('İkiniz de ${currentUser.city!.trim()}\'desiniz.');
    }

    score = score.clamp(35, 98);
    if (commonalities.isEmpty) {
      commonalities.add('Ortak müzik ve etkinlik zevkleriniz var!');
    }

    return {
      'score': score,
      'commonalities': commonalities,
    };
  }

  void clearUserData() {
    currentUser = UserModel(
      id: 'guest',
      name: 'Misafir Kullanıcı',
      avatarUrl: '',
      avatarUrls: [],
      pastEvents: [],
      plannedEvents: [],
      socialLinks: [],
      tags: [],
    );
    notifyListeners();
  }
}
