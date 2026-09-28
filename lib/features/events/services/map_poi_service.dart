import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/map_poi_model.dart';
import 'package:geolocator/geolocator.dart';

class MapPoiService {
  static final MapPoiService _instance = MapPoiService._internal();
  factory MapPoiService() => _instance;
  MapPoiService._internal();

  List<MapPoiModel> _ibbParkingLots = [];
  bool _isLoadingIbb = false;
  bool get isLoadingIbb => _isLoadingIbb;
  DateTime? _lastIbbFetchTime;

  List<MapPoiModel> _osmGasStations = [];
  bool _isLoadingOsmGas = false;
  bool get isLoadingOsmGas => _isLoadingOsmGas;
  double? _lastOsmGasLat;
  double? _lastOsmGasLng;
  DateTime? _lastOsmGasFetchTime;

  /// OpenStreetMap Overpass API üzerinden kullanıcının etrafındaki canlı benzinlikleri çeker
  Future<List<MapPoiModel>> fetchOsmGasStations({
    required double lat,
    required double lng,
    double radiusMeters = 6000,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _osmGasStations.isNotEmpty && _lastOsmGasFetchTime != null && _lastOsmGasLat != null && _lastOsmGasLng != null) {
      final diffTime = DateTime.now().difference(_lastOsmGasFetchTime!);
      final distMeters = Geolocator.distanceBetween(lat, lng, _lastOsmGasLat!, _lastOsmGasLng!);
      if (diffTime < const Duration(minutes: 5) && distMeters < 1500) {
        return _osmGasStations;
      }
    }

    _isLoadingOsmGas = true;
    try {
      final query = '[out:json][timeout:10];(node["amenity"="fuel"](around:${radiusMeters.round()},$lat,$lng);way["amenity"="fuel"](around:${radiusMeters.round()},$lat,$lng););out center 35;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'EventMatchApp/1.0 (contact@eventmatch.app)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final elements = decoded['elements'];
        if (elements is List && elements.isNotEmpty) {
          final List<MapPoiModel> list = [];
          for (var item in elements) {
            if (item is! Map) continue;
            final tags = item['tags'];
            if (tags is! Map) continue;

            double? itemLat;
            double? itemLng;

            if (item['lat'] != null && item['lon'] != null) {
              itemLat = double.tryParse(item['lat'].toString());
              itemLng = double.tryParse(item['lon'].toString());
            } else if (item['center'] is Map) {
              itemLat = double.tryParse(item['center']['lat']?.toString() ?? '');
              itemLng = double.tryParse(item['center']['lon']?.toString() ?? '');
            }

            if (itemLat == null || itemLng == null) continue;

            final rawName = tags['name']?.toString() ?? tags['brand']?.toString() ?? tags['operator']?.toString() ?? 'Benzin İstasyonu';
            final brand = tags['brand']?.toString() ?? tags['operator']?.toString() ?? 'Akaryakıt İstasyonu';
            final openingHours = tags['opening_hours']?.toString() ?? '24 Saat Açık';

            final List<String> perks = [];
            if (tags['shop'] == 'yes' || tags['shop'] == 'convenience') perks.add('Market');
            if (tags['car_wash'] == 'yes') perks.add('Oto Yıkama');
            if (tags['compressed_air'] == 'yes') perks.add('Lastik Hava');
            if (tags['fuel:lpg'] == 'yes') perks.add('LPG');
            if (tags['charging_station'] == 'yes') perks.add('⚡ Şarj');

            final desc = perks.isNotEmpty
                ? '$openingHours • ${perks.join(' • ')}'
                : (tags['addr:street'] != null ? '${tags['addr:street']} • $openingHours' : openingHours);

            list.add(
              MapPoiModel(
                id: 'osm_gas_${item['id'] ?? list.length}',
                title: rawName,
                description: desc,
                latitude: itemLat,
                longitude: itemLng,
                type: PoiType.gasStation,
                brandOrOperator: brand,
                feeOrCapacity: openingHours.contains('24/7') || openingHours.contains('00:00-00:00') ? '24 Saat Açık' : openingHours,
              ),
            );
          }

          if (list.isNotEmpty) {
            _osmGasStations = list;
            _lastOsmGasLat = lat;
            _lastOsmGasLng = lng;
            _lastOsmGasFetchTime = DateTime.now();
            debugPrint('[MapPoiService] OpenStreetMap Overpass: ${list.length} canlı benzinlik yüklendi.');
          }
        }
      }
    } catch (e) {
      debugPrint('[MapPoiService] OSM Overpass Gas API hatası: $e');
    } finally {
      _isLoadingOsmGas = false;
    }
    return _osmGasStations;
  }

  /// İBB Açık Veri Portalı İspark Canlı REST API'sinden anlık otoparkları çeker
  Future<List<MapPoiModel>> fetchIbbParkingLots({bool forceRefresh = false}) async {
    if (!forceRefresh && _ibbParkingLots.isNotEmpty && _lastIbbFetchTime != null) {
      if (DateTime.now().difference(_lastIbbFetchTime!) < const Duration(minutes: 5)) {
        return _ibbParkingLots;
      }
    }

    _isLoadingIbb = true;
    try {
      final response = await http.get(
        Uri.parse('https://api.ibb.gov.tr/ispark/Park'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final List<MapPoiModel> list = [];
          for (var item in decoded) {
            if (item is! Map) continue;
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lng = double.tryParse(item['lng']?.toString() ?? '');
            if (lat == null || lng == null || lat < 40.5 || lat > 41.6 || lng < 28.0 || lng > 30.0) {
              continue;
            }
            final int? total = item['capacity'] is int
                ? item['capacity']
                : int.tryParse(item['capacity']?.toString() ?? '');
            final int? empty = item['emptyCapacity'] is int
                ? item['emptyCapacity']
                : int.tryParse(item['emptyCapacity']?.toString() ?? '');
            final String rawName = (item['parkName']?.toString() ?? 'İspark Otoparkı').trim();
            final String parkName = rawName.toLowerCase().startsWith('ispark') || rawName.toLowerCase().startsWith('i̇spark')
                ? rawName
                : 'İspark $rawName';
            final String parkType = (item['parkType']?.toString() ?? 'Otopark').trim();
            final String district = (item['district']?.toString() ?? 'İstanbul').trim();
            final String workHours = (item['workHours']?.toString() ?? '24 Saat').trim();
            final int freeTime = item['freeTime'] is int
                ? item['freeTime']
                : (int.tryParse(item['freeTime']?.toString() ?? '') ?? 0);

            String feeOrCapText = '';
            if (empty != null) {
              feeOrCapText = empty > 0 ? '$empty Boş Yer • $parkType' : 'DOLU (0 Boş) • $parkType';
            } else {
              feeOrCapText = parkType;
            }

            list.add(
              MapPoiModel(
                id: 'ibb_${item['parkID'] ?? list.length}',
                title: parkName,
                description: '$district • $workHours${freeTime > 0 ? ' • İlk $freeTime dk ücretsiz' : ''}',
                latitude: lat,
                longitude: lng,
                type: PoiType.parking,
                brandOrOperator: 'İBB / İspark',
                feeOrCapacity: feeOrCapText,
                totalCapacity: total,
                emptyCapacity: empty,
                workHours: workHours,
                district: district,
                isIbb: true,
              ),
            );
          }
          if (list.isNotEmpty) {
            _ibbParkingLots = list;
            _lastIbbFetchTime = DateTime.now();
            debugPrint('[MapPoiService] İBB İspark API: ${list.length} otopark başarıyla yüklendi.');
          }
        }
      }
    } catch (e) {
      debugPrint('[MapPoiService] İBB İspark API bağlantı hatası: $e');
    } finally {
      _isLoadingIbb = false;
    }
    return _ibbParkingLots;
  }

  final List<MapPoiModel> _curatedPois = const [
    // ==========================================
    // 🅿️ OTOPARKLAR - İSTANBUL
    // ==========================================
    MapPoiModel(
      id: 'park_1',
      title: 'İspark Zorlu Center Kapalı Otoparkı',
      description: 'Levazım, Beşiktaş • 24 Saat Açık',
      latitude: 41.0668,
      longitude: 29.0175,
      type: PoiType.parking,
      brandOrOperator: 'İspark / Zorlu',
      feeOrCapacity: 'Kapalı • 2500+ Araç ⚡',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_2',
      title: 'Harbiye Açık Hava Cemil Topuzlu Otoparkı',
      description: 'Harbiye, Şişli • Etkinlik Alanı Yanı',
      latitude: 41.0465,
      longitude: 28.9902,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Açık & Katlı • 600 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_3',
      title: 'Volkswagen Arena & UNIQ İstanbul Otoparkı',
      description: 'Huzur Mah. Maslak, Sarıyer',
      latitude: 41.1070,
      longitude: 29.0115,
      type: PoiType.parking,
      brandOrOperator: 'UNIQ Otopark',
      feeOrCapacity: 'Kapalı • 1200 Araç ⚡',
    ),
    MapPoiModel(
      id: 'park_4',
      title: 'Bostancı Gösteri Merkezi Açık Otoparkı',
      description: 'Bostancı Mah. Kadıköy • BGM Önü',
      latitude: 40.9575,
      longitude: 29.0965,
      type: PoiType.parking,
      brandOrOperator: 'BGM Otopark',
      feeOrCapacity: 'Açık Otopark • 500 Araç',
    ),
    MapPoiModel(
      id: 'park_5',
      title: 'İspark Kadıköy Rıhtım & Balon Otoparkı',
      description: 'Caferağa Mah. Kadıköy Sahil',
      latitude: 40.9925,
      longitude: 29.0225,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Geniş Zemin • 800 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_6',
      title: 'İspark Beşiktaş Meydan Katlı Otoparkı',
      description: 'Sinanpaşa Mah. Beşiktaş Çarşı Yakını',
      latitude: 41.0428,
      longitude: 29.0068,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Katlı Otopark • 450 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_7',
      title: 'Ülker Sports Arena Doğu & Batı Otoparkı',
      description: 'Barbaros Mah. Ataşehir',
      latitude: 40.9942,
      longitude: 29.1175,
      type: PoiType.parking,
      brandOrOperator: 'Fenerbahçe Spor Kompleksi',
      feeOrCapacity: 'Kapalı • 1500 Araç ⚡',
    ),
    MapPoiModel(
      id: 'park_8',
      title: 'İspark Maslak Ayazağa Metro Otoparkı',
      description: 'Büyükdere Cad. Maslak, Sarıyer',
      latitude: 41.1118,
      longitude: 29.0205,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Park Et Devam Et • 650 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_9',
      title: 'Sinan Erdem Spor Kompleksi Otoparkı',
      description: 'Zuhuratbaba Mah. Bakırköy',
      latitude: 40.9882,
      longitude: 28.8685,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Geniş Açık Alan • 1000 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_10',
      title: 'KüçükÇiftlik Park Maçka Demokrasi Otoparkı',
      description: 'Harbiye Mah. Maçka, Şişli',
      latitude: 41.0425,
      longitude: 28.9930,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Zemin Otopark • 350 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_11',
      title: 'İspark Moda Sahil Otoparkı',
      description: 'Moda Cad. Kadıköy Sahil Şeridi',
      latitude: 40.9810,
      longitude: 29.0270,
      type: PoiType.parking,
      brandOrOperator: 'İspark',
      feeOrCapacity: 'Sahil Zemin • 300 Araç',
      isIbb: true,
    ),
    MapPoiModel(
      id: 'park_12',
      title: 'Vadistanbul AVM & Konser Alanı Otoparkı',
      description: 'Ayazağa Mah. Cendere Cad. Sarıyer',
      latitude: 41.1042,
      longitude: 28.9880,
      type: PoiType.parking,
      brandOrOperator: 'Vadistanbul',
      feeOrCapacity: 'Ücretsiz 3 Saat • 4000 Araç ⚡',
    ),

    // ==========================================
    // 🅿️ OTOPARKLAR - ANKARA & İZMİR
    // ==========================================
    MapPoiModel(
      id: 'park_13',
      title: 'Congresium Ankara Kapalı Otoparkı',
      description: 'Söğütözü Mah. Çankaya, Ankara',
      latitude: 39.9142,
      longitude: 32.8080,
      type: PoiType.parking,
      brandOrOperator: 'ATO Congresium',
      feeOrCapacity: 'Kapalı • 2000 Araç',
    ),
    MapPoiModel(
      id: 'park_14',
      title: 'CSO Ada Ankara Yerleşkesi Otoparkı',
      description: 'Talatpaşa Bulvarı Altındağ, Ankara',
      latitude: 39.9325,
      longitude: 32.8490,
      type: PoiType.parking,
      brandOrOperator: 'Kültür Bakanlığı',
      feeOrCapacity: 'Kapalı • 800 Araç ⚡',
    ),
    MapPoiModel(
      id: 'park_15',
      title: 'İzmir Kültürpark Fuar Yeraltı Otoparkı',
      description: 'Şair Eşref Bulvarı Konak, İzmir',
      latitude: 38.4285,
      longitude: 27.1455,
      type: PoiType.parking,
      brandOrOperator: 'İzmir Büyükşehir / İzelman',
      feeOrCapacity: 'Yeraltı • 1150 Araç',
    ),
    MapPoiModel(
      id: 'park_16',
      title: 'Bostanlı Suat Taşer Açık Otoparkı',
      description: 'Cemal Gürsel Cad. Karşıyaka, İzmir',
      latitude: 38.4550,
      longitude: 27.0980,
      type: PoiType.parking,
      brandOrOperator: 'İzelman',
      feeOrCapacity: 'Sahil Otopark • 400 Araç',
    ),

    // ==========================================
    // ⛽ BENZİNLİKLER - İSTANBUL
    // ==========================================
    MapPoiModel(
      id: 'gas_1',
      title: 'Shell & Select Zincirlikuyu',
      description: 'Büyükdere Cad. No:112 Şişli / Beşiktaş',
      latitude: 41.0695,
      longitude: 29.0142,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Market • Oto Yıkama',
    ),
    MapPoiModel(
      id: 'gas_2',
      title: 'Opet Maslak Büyükdere',
      description: 'Büyükdere Cad. No:245 Sarıyer (Maslak Girişi)',
      latitude: 41.1145,
      longitude: 29.0232,
      type: PoiType.gasStation,
      brandOrOperator: 'Opet',
      feeOrCapacity: '24 Saat Açık • Ultramarket • Hızlı Şarj ⚡',
    ),
    MapPoiModel(
      id: 'gas_3',
      title: 'Shell Maslak Atatürk Oto Sanayi',
      description: 'Ahi Evran Cad. Maslak, Sarıyer',
      latitude: 41.1090,
      longitude: 29.0185,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Deli2go Kahve',
    ),
    MapPoiModel(
      id: 'gas_4',
      title: 'Petrol Ofisi Cendere Vadistanbul',
      description: 'Cendere Cad. Ayazağa, Sarıyer',
      latitude: 41.1015,
      longitude: 28.9895,
      type: PoiType.gasStation,
      brandOrOperator: 'Petrol Ofisi',
      feeOrCapacity: '24 Saat Açık • e-POwer Şarj ⚡',
    ),
    MapPoiModel(
      id: 'gas_5',
      title: 'Opet Dolmabahçe Sahil',
      description: 'Dolmabahçe Gazhane Cad. Beşiktaş',
      latitude: 41.0390,
      longitude: 28.9950,
      type: PoiType.gasStation,
      brandOrOperator: 'Opet',
      feeOrCapacity: '24 Saat Açık • Stadyum Yanı',
    ),
    MapPoiModel(
      id: 'gas_6',
      title: 'BP Barbaros Bulvarı',
      description: 'Barbaros Bulvarı No:74 Beşiktaş',
      latitude: 41.0535,
      longitude: 29.0080,
      type: PoiType.gasStation,
      brandOrOperator: 'BP / Wild Bean',
      feeOrCapacity: '24 Saat Açık • Cafe',
    ),
    MapPoiModel(
      id: 'gas_7',
      title: 'Opet Bostancı E-5 Sahil Bağlantısı',
      description: 'Bostancı Köprüsü Yanı Kadıköy',
      latitude: 40.9630,
      longitude: 29.0980,
      type: PoiType.gasStation,
      brandOrOperator: 'Opet',
      feeOrCapacity: '24 Saat Açık • Oto Yıkama',
    ),
    MapPoiModel(
      id: 'gas_8',
      title: 'Shell Kadıköy Söğütlüçeşme',
      description: 'Fahrettin Kerim Gökay Cad. Kadıköy',
      latitude: 40.9950,
      longitude: 29.0375,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Select Market',
    ),
    MapPoiModel(
      id: 'gas_9',
      title: 'Petrol Ofisi Kalamış Marina',
      description: 'Münir Nurettin Selçuk Cad. Kadıköy',
      latitude: 40.9785,
      longitude: 29.0410,
      type: PoiType.gasStation,
      brandOrOperator: 'Petrol Ofisi',
      feeOrCapacity: '24 Saat Açık • Marina Yanı',
    ),
    MapPoiModel(
      id: 'gas_10',
      title: 'Shell Ataşehir Bulvarı',
      description: 'Ataşehir Bulvarı No:18 Ataşehir',
      latitude: 40.9985,
      longitude: 29.1150,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Arena Yakını',
    ),
    MapPoiModel(
      id: 'gas_11',
      title: 'BP E-5 Bakırköy İncirli',
      description: 'E-5 Londra Asfaltı Bakırköy',
      latitude: 40.9980,
      longitude: 28.8720,
      type: PoiType.gasStation,
      brandOrOperator: 'BP',
      feeOrCapacity: '24 Saat Açık • Oto Bakım',
    ),
    MapPoiModel(
      id: 'gas_12',
      title: 'Shell Sahil Yolu Ataköy',
      description: 'Rauf Orbay Cad. Sahil Yolu Bakırköy',
      latitude: 40.9750,
      longitude: 28.8810,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Elektrikli Şarj ⚡',
    ),

    // ==========================================
    // ⛽ BENZİNLİKLER - ANKARA & İZMİR
    // ==========================================
    MapPoiModel(
      id: 'gas_13',
      title: 'Opet Söğütözü Eskişehir Yolu',
      description: 'Dumlupınar Bulvarı No:42 Çankaya, Ankara',
      latitude: 39.9120,
      longitude: 32.8040,
      type: PoiType.gasStation,
      brandOrOperator: 'Opet',
      feeOrCapacity: '24 Saat Açık • Congresium Yanı',
    ),
    MapPoiModel(
      id: 'gas_14',
      title: 'Shell Tunus Caddesi Çankaya',
      description: 'Tunus Cad. No:68 Kavaklıdere, Ankara',
      latitude: 39.9075,
      longitude: 32.8560,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Kızılay Yakını',
    ),
    MapPoiModel(
      id: 'gas_15',
      title: 'Opet Alsancak Liman',
      description: 'Atatürk Cad. Liman Girişi Konak, İzmir',
      latitude: 38.4390,
      longitude: 27.1510,
      type: PoiType.gasStation,
      brandOrOperator: 'Opet',
      feeOrCapacity: '24 Saat Açık • Kordon Yanı',
    ),
    MapPoiModel(
      id: 'gas_16',
      title: 'Shell Karşıyaka Yalı Caddesi',
      description: 'Cemal Gürsel Cad. No:212 Karşıyaka, İzmir',
      latitude: 38.4590,
      longitude: 27.1050,
      type: PoiType.gasStation,
      brandOrOperator: 'Shell',
      feeOrCapacity: '24 Saat Açık • Bostanlı Sahil',
    ),
  ];

  List<MapPoiModel> get allPois => [...getParkingLots(), ...getGasStations()];

  List<MapPoiModel> getParkingLots() {
    if (_ibbParkingLots.isNotEmpty) {
      // İBB otoparkları ile diğer şehirlerin otoparklarını birleştir
      final nonIstanbul = _curatedPois.where((p) => p.type == PoiType.parking && (p.latitude < 40.5 || p.latitude > 41.6 || p.longitude < 28.0 || p.longitude > 30.0)).toList();
      return [..._ibbParkingLots, ...nonIstanbul];
    }
    return _curatedPois.where((p) => p.type == PoiType.parking).toList();
  }

  List<MapPoiModel> getGasStations() {
    if (_osmGasStations.isNotEmpty) {
      return _osmGasStations;
    }
    return _curatedPois.where((p) => p.type == PoiType.gasStation).toList();
  }

  List<MapPoiModel> getNearbyParkingLots({
    double? lat,
    double? lng,
    double maxKm = 6.0,
    int limit = 30,
  }) {
    final all = getParkingLots();
    if (lat == null || lng == null) {
      return all.take(limit).toList();
    }

    final withDistance = all.map((poi) {
      final distMeters = Geolocator.distanceBetween(lat, lng, poi.latitude, poi.longitude);
      return MapEntry(poi, distMeters);
    }).toList();

    withDistance.sort((a, b) => a.value.compareTo(b.value));

    final filtered = withDistance
        .where((entry) => entry.value <= (maxKm * 1000))
        .map((entry) => entry.key)
        .take(limit)
        .toList();

    if (filtered.length < 8) {
      return withDistance.map((entry) => entry.key).take(15).toList();
    }

    return filtered;
  }

  List<MapPoiModel> getNearbyGasStations({
    double? lat,
    double? lng,
    double maxKm = 10.0,
    int limit = 20,
  }) {
    final all = getGasStations();
    if (lat == null || lng == null) {
      return all.take(limit).toList();
    }

    final withDistance = all.map((poi) {
      final distMeters = Geolocator.distanceBetween(lat, lng, poi.latitude, poi.longitude);
      return MapEntry(poi, distMeters);
    }).toList();

    withDistance.sort((a, b) => a.value.compareTo(b.value));

    final filtered = withDistance
        .where((entry) => entry.value <= (maxKm * 1000))
        .map((entry) => entry.key)
        .take(limit)
        .toList();

    if (filtered.length < 5) {
      return withDistance.map((entry) => entry.key).take(10).toList();
    }

    return filtered;
  }

  List<MapPoiModel> getNearbyPois({
    required double lat,
    required double lng,
    double maxKm = 25.0,
    PoiType? type,
  }) {
    final list = type == PoiType.parking
        ? getParkingLots()
        : (type == PoiType.gasStation ? getGasStations() : allPois);

    return list.where((p) {
      final distanceInMeters = Geolocator.distanceBetween(lat, lng, p.latitude, p.longitude);
      return distanceInMeters <= (maxKm * 1000);
    }).toList();
  }
}
