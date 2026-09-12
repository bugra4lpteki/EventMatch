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
    // A. Anında render: Önbellek sürümü kontrolü (Eski önbelleği tamamen sil ve sıfırdan Ticketmaster ile başlat)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheVersion = prefs.getInt('eventmatch_cache_version_num') ?? 0;
      if (cacheVersion < 7) {
        await prefs.remove(_eventsCacheKey);
        await prefs.setInt('eventmatch_cache_version_num', 7);
        _events.clear();
      } else {
        await _loadEventsFromCache();
      }
    } catch (_) {}

    // Eski harici API ve mock görsellerini temizle (Yalnızca Ticketmaster fotoğrafları)
    _events.removeWhere((e) =>
        e.imageUrl.contains('dzcdn.net') ||
        e.imageUrl.contains('spotifycdn.com') ||
        e.id.toLowerCase().contains('biletinial'));

    // Her zaman Ticketmaster resmi vitrin etkinliklerini yükle
    _populateFallbackEvents();

    _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _loadLocalAttendeesCache();
    _syncPlannedEventsWithAttendees();
    notifyListeners(); // Kullanıcı anasayfayı 0.05 saniyede dolu olarak görür!

    // B. Arka planda sessizce Canlı Biletix API'lerini güncelle
    _fetchLiveEventsInBackground();
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
        final results = await Future.wait([
          service.fetchLiveTicketmasterEvents(page: 0, size: 100),
          service.fetchLiveTicketmasterEvents(page: 1, size: 100),
          service.fetchLiveTicketmasterEvents(keyword: 'baturay'),
          service.fetchLiveTicketmasterEvents(keyword: 'duman'),
          service.fetchLiveTicketmasterEvents(keyword: 'levent'),
          service.fetchLiveTicketmasterEvents(keyword: 'teoman'),
          service.fetchLiveTicketmasterEvents(keyword: 'tiyatro'),
          service.fetchLiveTicketmasterEvents(keyword: 'stand up'),
          service.fetchLiveTicketmasterEvents(keyword: 'konser'),
          service.fetchLiveSportsEvents(),
        ]);

        bool addedAny = false;
        for (var list in results) {
          for (var live in list) {
            final idx = _events.indexWhere((e) => e.id == live.id);
            if (idx < 0) {
              _events.add(live);
              addedAny = true;
            } else {
              // Biletix/Passo'dan gelen yeni tarih, saat ve bilet linkleri ile güncelle
              _events[idx] = live;
              addedAny = true;
            }
          }
        }
        if (addedAny) {
          _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
          await _saveEventsToCache();
          notifyListeners();
        }
        debugPrint('[EventService] 🎟️ Biletix & Canlı Spor (Passo) müsabakaları senkronize edildi: ${_events.length}');
      } catch (e) {
        debugPrint('[EventService] Canlı Biletix & Spor API çekme hatası: $e');
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
              .select('id, name, username, city')
              .inFilter('id', userIds);
          for (var u in usersRes) {
            final id = u['id'].toString();
            usersMap[id.toLowerCase()] = UserModel(
              id: id,
              name: u['name']?.toString() ?? 'Kullanıcı',
              username: u['username']?.toString(),
              city: u['city']?.toString(),
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
            if (usersMap.containsKey(uid) && photo.isNotEmpty && (usersMap[uid]!.avatarUrl.isEmpty || usersMap[uid]!.avatarUrl.contains('user_avatar'))) {
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
              final uRes = await _supabase.from('users').select('name').eq('id', rawUserId).maybeSingle();
              String attendeeAvatar = '';
              try {
                final pRes = await _supabase.from('user_photos').select('storage_url').eq('user_id', rawUserId).eq('is_active', true).order('sort_order', ascending: true).limit(1).maybeSingle();
                if (pRes != null && pRes['storage_url'] != null) {
                  attendeeAvatar = pRes['storage_url'].toString();
                }
              } catch (_) {}
              if (uRes != null) {
                attendee = UserModel(id: rawUserId, name: uRes['name'] ?? 'Katılımcı', avatarUrl: attendeeAvatar);
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
        id: 'biletix_Z1HyzZyMZk2Qaely',
        title: 'The Black Keys',
        category: 'Konser',
        location: 'Maximum UNIQ Açıkhava, İstanbul',
        dateTime: now.add(const Duration(days: 3, hours: 21)),
        description: 'Grammy ödüllü rock devi The Black Keys, dünya turnesi kapsamında İstanbul sahnesinde canlı performansıyla dinleyicilerle buluşuyor!',
        imageUrl: 'https://s1.ticketm.net/dam/a/1a5/c5f563b8-baf5-4342-97e6-b4a9147c51a5_SOURCE',
        latitude: 41.1114,
        longitude: 29.0233,
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=the+black+keys',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=saint+levant',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=black+veil+brides',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=snarky+puppy',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=black+label+society',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=mavi',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=bilal',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=arturo+sandoval',
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
        ticketUrl: 'https://www.biletix.com/search/TURKIYE/tr?category=&searchinfo=swallow+the+sun',
        ticketProvider: 'Biletix',
        atmosphere: '⚡ Doom Metal',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_gs_bjk_derbi',
        title: 'Galatasaray - Beşiktaş',
        category: 'Spor',
        location: 'RAMS Park Stadyumu, İstanbul',
        dateTime: now.add(const Duration(days: 4, hours: 20)),
        description: 'Trendyol Süper Lig Dev Derbi heyecanı! RAMS Park tribünlerinde dev derbide taraftarlar buluşuyor. Biletler Passo üzerinden satışta.',
        imageUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop',
        latitude: 41.1032,
        longitude: 28.9912,
        ticketUrl: 'https://www.passo.com.tr/tr/etkinlik-ara/spor?aranan=Galatasaray',
        ticketProvider: 'Passo',
        atmosphere: '🔥 Dev Derbi',
        isPopular: true,
      ),
      EventModel(
        id: 'fenerbahce_1',
        title: 'Fenerbahçe Beko vs Anadolu Efes',
        category: 'Spor',
        location: 'Ülker Spor ve Etkinlik Salonu, İstanbul',
        dateTime: now.add(const Duration(days: 7, hours: 19)),
        description: 'EuroLeague ve Türkiye Sigorta Basketbol Süper Ligi dev derbisinde Ülker Arena sahnesinde kıyasıya mücadele.',
        imageUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=1200&auto=format&fit=crop',
        latitude: 40.9934,
        longitude: 29.1093,
        ticketUrl: 'https://www.passo.com.tr/tr/arama?q=fenerbahce+beko',
        ticketProvider: 'Passo',
        atmosphere: '⚡ Heyecanlı',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_bjk_ts_derbi',
        title: 'Beşiktaş - Trabzonspor',
        category: 'Spor',
        location: 'Tüpraş Stadyumu, İstanbul',
        dateTime: now.add(const Duration(days: 6, hours: 19)),
        description: 'Beşiktaş Tüpraş Stadyumu\'nda Trabzonspor\'u konuk ediyor. Muhteşem Boğaz manzaralı stadyumda maç coşkusuna katıl!',
        imageUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?q=80&w=1200&auto=format&fit=crop',
        latitude: 41.0392,
        longitude: 28.9946,
        ticketUrl: 'https://www.passo.com.tr/tr/etkinlik-ara/spor?aranan=Be%C5%9Fikta%C5%9F',
        ticketProvider: 'Passo',
        atmosphere: '🔥 Büyük Maç',
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
            currentUser.avatarUrls = cachedUrls.where((u) => u.startsWith('http') || u.startsWith('assets/')).toList();
            if (currentUser.avatarUrls.isNotEmpty) {
              currentUser.avatarUrl = currentUser.avatarUrls.first;
            }
          }
        }
        if (currentUser.avatarUrl.isEmpty || currentUser.avatarUrl == 'assets/images/user_avatar.jpg') {
          final cachedSingle = prefs.getString('${userId}_userAvatarUrl');
          currentUser.avatarUrl = (cachedSingle != null && cachedSingle.startsWith('http'))
              ? cachedSingle
              : '';
          if (currentUser.avatarUrl.isNotEmpty && currentUser.avatarUrls.isEmpty) {
            currentUser.avatarUrls = [currentUser.avatarUrl];
          }
        }
        currentUser.avatarUrls = currentUser.avatarUrls.where((u) => u != 'assets/images/user_avatar.jpg').toList();
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

    _syncPlannedEventsWithAttendees();
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

  List<String> categories = ['Tümü', '🌟 Sana Özel', '🔥 Popüler', '💖 Eşleşme Oranı Yüksek', 'Konser', 'Tiyatro', 'Stand-up', 'Spor', 'Festival'];
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
  String _selectedCity = 'Tüm Şehirler';
  String _searchQuery = '';

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
    final active = _events.where((e) => e.isActive && e.dateTime.isAfter(now.subtract(const Duration(days: 1)))).toList();
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
  String get selectedCity => _selectedCity;
  String get searchQuery => _searchQuery;

  List<EventModel> getAdminEvents() => [..._events];

  void setCategory(String category) {
    _selectedCategory = category;
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
        if (!_events.any((e) => e.id == live.id || e.title.toLowerCase() == live.title.toLowerCase())) {
          _events.add(live);
          addedAny = true;
        }
      }
      if (addedAny) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EventService] Live search error: $e');
    }
  }

  void addCategory(String category) {
    if (!categories.contains(category)) {
      categories.add(category);
      notifyListeners();
    }
  }

  void addEvent(EventModel event) {
    _events.insert(0, event);
    notifyListeners();
  }

  void updateEvent(EventModel event) {
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
    List<EventModel> activeEvents = _events.where((e) => e.isActive && e.dateTime.isAfter(now.subtract(const Duration(days: 1)))).toList();

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
      final catNorm = _normalizeText(e.category);
      if (selectedNorm == 'konser') {
        return catNorm.contains('konser') || catNorm.contains('music') || catNorm.contains('müzik') || catNorm.contains('pop') || catNorm.contains('rock');
      }
      if (selectedNorm == 'tiyatro') {
        return catNorm.contains('tiyatro') || catNorm.contains('theatre') || catNorm.contains('art');
      }
      if (selectedNorm == 'spor') {
        return catNorm.contains('spor') || catNorm.contains('sport') || catNorm.contains('futbol') || catNorm.contains('basketbol') || catNorm.contains('voleybol') || catNorm.contains('derbi') || catNorm.contains('lig');
      }
      return catNorm.contains(selectedNorm);
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

  List<EventModel> get allEvents => _events.where((e) => e.dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 6)))).toList();

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
            'message': item['message'],
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
        'message': m['message'],
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
            .where((id) => id != null && _isValidUuid(id!))
            .cast<String>()
            .toSet()
            .toList();

        Map<String, String> senderNames = {};
        if (senderIds.isNotEmpty) {
          try {
            final uRes = await _supabase.from('users').select('id, name').inFilter('id', senderIds);
            for (var u in uRes) {
              senderNames[u['id'].toString().toLowerCase()] = u['name']?.toString() ?? 'Kullanıcı';
            }
          } catch (_) {}
        }

        for (var row in res) {
          final sId = row['sender_id']?.toString() ?? '';
          final lowerSId = sId.toLowerCase();
          final isMe = lowerSId == currentUserId.toLowerCase();
          list.add({
            'userId': sId,
            'userName': isMe ? currentUser.name : (senderNames[lowerSId] ?? 'Kullanıcı'),
            'message': row['content']?.toString() ?? row['message']?.toString() ?? '',
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
              final msg = payload['message']?.toString() ?? '';
              if (msg.trim().isEmpty) return;

              _venueChats.putIfAbsent(eventId, () => []);
              if (!_venueChats[eventId]!.any((m) => m['message'] == msg && m['userId'] == sId)) {
                _venueChats[eventId]!.add({
                  'userId': sId,
                  'userName': sId.toLowerCase() == currentUserId.toLowerCase() ? currentUser.name : sName,
                  'message': msg,
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

  Future<void> sendVenueMessage(String eventId, String message) async {
    final text = message.trim();
    if (text.isEmpty) return;

    final uid = currentUserId;
    final uName = currentUser.name;
    final now = DateTime.now();

    _venueChats.putIfAbsent(eventId, () => []);
    _venueChats[eventId]!.add({
      'userId': uid,
      'userName': uName,
      'message': text,
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
          'message': text,
          'time': now.toIso8601String(),
        },
      );
    } catch (_) {}

    // 2. Supabase messages tablosuna kalıcı olarak yaz
    try {
      await _supabase.from('messages').insert({
        'sender_id': uid,
        'receiver_id': 'venue_$eventId',
        'content': text,
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
