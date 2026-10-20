import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/after_party_spot_model.dart';
import '../models/event_model.dart';

class AfterPartyService extends ChangeNotifier {
  static final AfterPartyService _instance = AfterPartyService._internal();
  factory AfterPartyService() => _instance;
  AfterPartyService._internal();

  final Map<String, List<AfterPartySpotModel>> _spotsCache = {};
  final Set<String> _joinedSpotIds = {};

  bool isUserJoined(String spotId) => _joinedSpotIds.contains(spotId);

  List<AfterPartySpotModel> getCachedSpots(String eventId) {
    return _spotsCache[eventId] ?? [];
  }

  Future<List<AfterPartySpotModel>> getSpotsForEvent(EventModel event) async {
    final eventId = event.id;
    if (_spotsCache.containsKey(eventId) && _spotsCache[eventId]!.isNotEmpty) {
      return _spotsCache[eventId]!;
    }

    final lat = event.latitude ?? 41.042;
    final lng = event.longitude ?? 28.995;

    final List<AfterPartySpotModel> spots = [];

    // 1. Try fetching from OpenStreetMap Overpass API (Real-time live nearby pubs/bars)
    try {
      final query = '[out:json][timeout:8];'
          'node(around:1200,$lat,$lng)[amenity~"bar|pub|nightclub|biergarten"];'
          'out 15;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = (data['elements'] as List? ?? []);

        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name']?.toString() ?? tags['name:tr']?.toString() ?? tags['brand']?.toString();
          if (name == null || name.trim().isEmpty) continue;

          final nodeLat = (el['lat'] as num).toDouble();
          final nodeLon = (el['lon'] as num).toDouble();
          final amenity = tags['amenity']?.toString() ?? 'bar';

          String cat = 'Pub & Bira';
          if (amenity == 'nightclub') cat = 'Gece Kulübü';
          if (amenity == 'bar') cat = 'Kokteyl & Bar';

          final street = tags['addr:street']?.toString() ?? tags['addr:suburb']?.toString() ?? 'Yakın Çevre';

          spots.add(AfterPartySpotModel.fromMap({
            'id': 'osm_${el['id']}',
            'event_id': eventId,
            'name': name,
            'category': cat,
            'address': street,
            'latitude': nodeLat,
            'longitude': nodeLon,
            'attendee_names': _generateSimulatedAttendees(name.hashCode),
          }, eventLat: lat, eventLng: lng));
        }
      }
    } catch (e) {
      debugPrint('[AfterPartyService] Overpass live fetch note: $e');
    }

    // 2. Fetch User-Created spots from Supabase
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('after_party_spots')
          .select()
          .eq('event_id', eventId);

      final fetchedUgc = (res as List)
          .map((item) => AfterPartySpotModel.fromMap(Map<String, dynamic>.from(item), eventLat: lat, eventLng: lng))
          .toList();

      for (final ugc in fetchedUgc) {
        if (!spots.any((s) => s.id == ugc.id)) {
          spots.insert(0, ugc);
        }
      }
    } catch (e) {
      debugPrint('[AfterPartyService] Supabase UGC fetch note: $e');
    }

    // 3. Fallback Curated Spots for Turkey's prime event venues if spots is low
    if (spots.length < 3) {
      spots.addAll(_getCuratedFallbackSpots(event, lat, lng));
    }

    // Sort by distance (closest first)
    spots.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    _spotsCache[eventId] = spots;
    notifyListeners();
    return spots;
  }

  List<String> _generateSimulatedAttendees(int seed) {
    final names = [
      'Emre Can', 'Selin Yılmaz', 'Alp Kaya', 'Deniz Akın', 'Ece Demir',
      'Burak Çelik', 'Melis Arslan', 'Kaan Yıldız', 'Gizem Şen', 'Oğuzhan K.'
    ];
    final count = (seed.abs() % 5) + 2; // 2 to 6 people
    final result = <String>[];
    for (int i = 0; i < count; i++) {
      result.add(names[(seed.abs() + i) % names.length]);
    }
    return result;
  }

  List<AfterPartySpotModel> _getCuratedFallbackSpots(EventModel event, double lat, double lng) {
    final title = event.title.toLowerCase();
    final loc = event.location.toLowerCase();

    // Beşiktaş / Harbiye / Maçka (KüçükÇiftlik Park civarı)
    if (loc.contains('küçükçiftlik') || loc.contains('harbiye') || loc.contains('maçka') || loc.contains('beşiktaş')) {
      return [
        AfterPartySpotModel(
          id: 'curated_1',
          eventId: event.id,
          name: 'The United Pub Beşiktaş',
          category: 'Pub & Bira',
          address: 'Sinanpaşa, Şair Nedim Cd. No:18, Beşiktaş',
          latitude: 41.0427,
          longitude: 29.0062,
          distanceMeters: 450,
          walkingMinutes: 6,
          note: 'Geniş bira menüsü ve dış alan masaları var.',
          attendeeNames: ['Selin Kaya', 'Burak Demir', 'Efe Yıldız', 'Zeynep Ak'],
        ),
        AfterPartySpotModel(
          id: 'curated_2',
          eventId: event.id,
          name: 'Joker No:19 Beşiktaş',
          category: 'Kokteyl & Bar',
          address: 'Vişnezade, Süleyman Seba Cd. No:19',
          latitude: 41.0415,
          longitude: 29.0005,
          distanceMeters: 620,
          walkingMinutes: 8,
          note: 'Konser çıkışı en popüler toplanma ve kutlama noktası.',
          attendeeNames: ['Kaan Tekin', 'Melis Kurt', 'Deniz Arı'],
        ),
        AfterPartySpotModel(
          id: 'curated_3',
          eventId: event.id,
          name: 'Kafes / Park Sahne Buluşması',
          category: 'Toplanma Noktası',
          address: 'Maçka Parkı Girişi',
          latitude: 41.0435,
          longitude: 28.9942,
          distanceMeters: 280,
          walkingMinutes: 3,
          isUserCreated: true,
          createdByName: 'Ahmet (EventMatch)',
          note: 'Konser bitince çimlerde toplanıp sohbet ediyoruz!',
          attendeeNames: ['Ahmet Kaya', 'Ezgi Şen', 'Doruk B.', 'Caner O.'],
        ),
      ];
    }

    // Kadıköy & Moda (Kadıköy Sahne, Moda Kayıkhane)
    if (loc.contains('kadıköy') || loc.contains('moda') || loc.contains('bostancı')) {
      return [
        AfterPartySpotModel(
          id: 'curated_k1',
          eventId: event.id,
          name: 'Karga Bar Kadıköy',
          category: 'Bar & Alternatif',
          address: 'Caferağa, Kadife Sk. No:16 (Barlar Sokağı)',
          latitude: 40.9882,
          longitude: 29.0275,
          distanceMeters: 380,
          walkingMinutes: 5,
          note: 'Tarihi köşk atmosferi ve indie müzik.',
          attendeeNames: ['Okan Vural', 'Ece Dinçer', 'Tolga Tan'],
        ),
        AfterPartySpotModel(
          id: 'curated_k2',
          eventId: event.id,
          name: 'Zeplin Pub & Delicatessen',
          category: 'Pub & Craft Bira',
          address: 'Caferağa, Moda Cd. No:70, Kadıköy',
          latitude: 40.9855,
          longitude: 29.0298,
          distanceMeters: 550,
          walkingMinutes: 7,
          note: 'Özel fıçı biralar ve sıcak ortam.',
          attendeeNames: ['Buse Çelik', 'Görkem S.', 'Aylin Y.'],
        ),
      ];
    }

    // Genel Şehir Merkezleri
    return [
      AfterPartySpotModel(
        id: 'curated_g1',
        eventId: event.id,
        name: 'The Populist',
        category: 'Craft Bira & Gastropub',
        address: 'Etkinlik Alanı Çevresi (1. Cadde)',
        latitude: lat + 0.003,
        longitude: lng + 0.002,
        distanceMeters: 360,
        walkingMinutes: 4,
        note: 'Konser sonrası DJ performansı ve gece atıştırmalıkları.',
        attendeeNames: ['Serkan B.', 'Zehra D.', 'Mert K.'],
      ),
      AfterPartySpotModel(
        id: 'curated_g2',
        eventId: event.id,
        name: 'Retro Kokteyl & Lounge',
        category: 'Kokteyl & Bar',
        address: 'Ana Cadde Üzeri No:42',
        latitude: lat + 0.005,
        longitude: lng - 0.003,
        distanceMeters: 590,
        walkingMinutes: 7,
        note: 'İmza kokteyller ve rahat müzik.',
        attendeeNames: ['Derya Kaya', 'Barış Ö.'],
      ),
    ];
  }

  void toggleJoinSpot(String eventId, String spotId, String userName) {
    final list = _spotsCache[eventId];
    if (list == null) return;

    final index = list.indexWhere((s) => s.id == spotId);
    if (index == -1) return;

    final current = list[index];
    final updatedAttendees = List<String>.from(current.attendeeNames);

    if (_joinedSpotIds.contains(spotId)) {
      _joinedSpotIds.remove(spotId);
      updatedAttendees.remove(userName);
    } else {
      _joinedSpotIds.add(spotId);
      if (!updatedAttendees.contains(userName)) {
        updatedAttendees.add(userName);
      }
    }

    list[index] = current.copyWith(attendeeNames: updatedAttendees);
    notifyListeners();
  }

  Future<void> addCustomSpot({
    required EventModel event,
    required String name,
    required String category,
    required String note,
    required String creatorName,
    required String creatorId,
  }) async {
    final eventLat = event.latitude ?? 41.042;
    final eventLng = event.longitude ?? 28.995;

    final newSpot = AfterPartySpotModel(
      id: 'ugc_${DateTime.now().millisecondsSinceEpoch}',
      eventId: event.id,
      name: name,
      category: category,
      address: '${event.location} Yakını',
      latitude: eventLat + 0.0015,
      longitude: eventLng + 0.0015,
      distanceMeters: 220,
      walkingMinutes: 3,
      note: note,
      isUserCreated: true,
      createdByName: creatorName,
      attendeeNames: [creatorName],
    );

    _joinedSpotIds.add(newSpot.id);

    _spotsCache.putIfAbsent(event.id, () => []);
    _spotsCache[event.id]!.insert(0, newSpot);
    notifyListeners();

    // Persist to Supabase if connected
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('after_party_spots').insert({
        'id': newSpot.id,
        'event_id': event.id,
        'name': name,
        'category': category,
        'address': newSpot.address,
        'latitude': newSpot.latitude,
        'longitude': newSpot.longitude,
        'note': note,
        'created_by': creatorId,
        'attendee_names': [creatorName],
        'is_user_created': true,
      });
    } catch (e) {
      debugPrint('[AfterPartyService] Supabase insert note: $e');
    }
  }
}
