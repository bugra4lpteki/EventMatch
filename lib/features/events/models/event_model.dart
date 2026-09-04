import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'user_model.dart';

class EventModel {
  final String id;
  final String title;
  final String category;
  final String location;
  final DateTime dateTime;
  final String description;
  final String imageUrl;
  final List<UserModel> attendees;
  final double? latitude;
  final double? longitude;
  final String? ticketUrl;
  final String? ticketProvider;
  bool isActive;

  EventModel({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.dateTime,
    required this.description,
    required String imageUrl,
    this.latitude,
    this.longitude,
    this.ticketUrl,
    this.ticketProvider,
    this.isActive = true,
    this.atmosphere = 'Sakin',
    this.isPopular = false,
    List<UserModel>? attendees,
  })  : imageUrl = _sanitizeImageUrl(imageUrl, title, category),
        attendees = attendees ?? [];

  static String _sanitizeImageUrl(String url, String title, String category) {
    final titleLower = title.toLowerCase();
    final catLower = category.toLowerCase();

    // Tiyatro, Stand-up ve Komedi etkinlikleri müzik sanatçısı eşleştirmelerinden hariç tutulur
    final isNonMusic = catLower.contains('theatre') ||
        catLower.contains('tiyatro') ||
        catLower.contains('arts') ||
        catLower.contains('stand-up') ||
        catLower.contains('standup') ||
        catLower.contains('komedi') ||
        catLower.contains('sahne') ||
        titleLower.contains('stand up') ||
        titleLower.contains('stand-up') ||
        titleLower.contains('tiyatro') ||
        titleLower.contains('gösteri') ||
        titleLower.contains('oyun') ||
        titleLower.contains('tek kişilik');

    if (isNonMusic) {
      if (titleLower.contains('baturay') || titleLower.contains('özdemir')) {
        return 'https://images.bursadabugun.com/editor/haber/18022023/baturay-ozdemir-stand-up-gosterisi-ile-bursada-63f08fe717e13.jpg';
      }
      if (url.isNotEmpty && !url.contains('photo-1470225620780') && !url.contains('photo-1514525253161')) {
        return url;
      }
      return 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?q=80&w=1200&auto=format&fit=crop';
    }

    // 1. Konser / Sanatçı Etkinlikleri İçin Gerçek Spotify Sanatçı Kapak (Artist Header) Görselleri
    if (titleLower.contains('sıla') || titleLower.contains('sila')) {
      // Sıla - Spotify Resmi Sanatçı Header/Profil Kapak Fotoğrafı (Siyah-Beyaz Çatı/Teras Oturan Sanatçı)
      return 'https://image-cdn-fa.spotifycdn.com/image/ab6761610000e5ebc6b5e030f9a843e7338bc5f1';
    }
    if (titleLower.contains('the sisters of mercy') || titleLower.contains('sisters of mercy')) {
      // The Sisters of Mercy - Resmi HD Sanatçı / Grup Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/d9ac1fd697d5ac6124413fa0441db6f1/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('the black keys') || titleLower.contains('black keys')) {
      // The Black Keys - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab67618600001016d97c724773c3cbdf1fe251b5';
    }
    if (titleLower.contains('buray')) {
      // Buray - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı (Alacalı)
      return 'https://i.scdn.co/image/ab6761860000101683beeb732a3fc267923707ce';
    }
    if (titleLower.contains('duman')) {
      // Duman - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab676186000010167c13286dc5ce2665e7178ebf';
    }
    if (titleLower.contains('levent yüksel') || titleLower.contains('levent yuksel')) {
      // Levent Yüksel - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab676186000010166ea344d18ecab55225c571e2';
    }
    if (titleLower.contains('gülşen') || titleLower.contains('gulsen')) {
      // Gülşen - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab676186000010168bfa17a42a083aa426d400e9';
    }
    if (titleLower.contains('blok3') || titleLower.contains('blok 3')) {
      // Blok3 - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab67618600001016a27e46fcb99cb5a3cb53ea24';
    }
    if (titleLower.contains('teoman')) {
      // Teoman - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab67618600001016629ad14cbb11eaef917e7939';
    }
    if (titleLower.contains('mor ve ötesi') || titleLower.contains('mor ve otesi')) {
      // Mor ve Ötesi - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab676186000010161b9ee77e9ec8fca3bb5976b9';
    }
    if (titleLower.contains('manga')) {
      // maNga - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab676186000010164c0cfb2e0be38cf4dc1dc1df';
    }
    if (titleLower.contains('athena')) {
      // Athena - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab67618600001016f4da31ce9c5658e0a30b58e6';
    }
    if (titleLower.contains('sezen aksu')) {
      // Sezen Aksu - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab6761860000101633d1c14cb5ee9a6927a7aa37';
    }
    if (titleLower.contains('tarkan')) {
      // Tarkan - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab6761860000101683995f5733f11d13a96860d5';
    }
    if (titleLower.contains('melike şahin') || titleLower.contains('melike sahin')) {
      // Melike Şahin - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab6761860000101639d67b2521f7c32bf26fb2ae';
    }
    if (titleLower.contains('madrigal')) {
      // Madrigal - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab67618600001016911c42f026131362e49c716a';
    }
    if (titleLower.contains('coldplay')) {
      // Coldplay - Spotify Resmi Sanatçı Header/Kapak Fotoğrafı
      return 'https://i.scdn.co/image/ab6761860000101693be6657dd8cf45dc82c572a';
    }

    // 2. Stand-up ve Komedi İçin Gerçek Görsel
    if (titleLower.contains('baturay') || titleLower.contains('özdemir')) {
      return 'https://images.bursadabugun.com/editor/haber/18022023/baturay-ozdemir-stand-up-gosterisi-ile-bursada-63f08fe717e13.jpg';
    }

    if (url.contains('a0f0fa47') || titleLower.contains('mavi')) {
      return 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?q=80&w=1470&auto=format&fit=crop';
    }

    // Generic, boş veya bozuk stok fotoğrafları kategorisine göre eşle (Hiçbir etkinlik boş kalmaz)
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty ||
        trimmedUrl.contains('weserv.nl') ||
        trimmedUrl.contains('placeholder') ||
        trimmedUrl.contains('photo-1470225620780-dba8ba36b745') ||
        trimmedUrl.contains('photo-1514525253161-7a46d19cd819')) {
      if (catLower.contains('theatre') || catLower.contains('tiyatro') || catLower.contains('arts') || titleLower.contains('stand up') || titleLower.contains('gösteri')) {
        return 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?q=80&w=1200&auto=format&fit=crop';
      } else if (catLower.contains('sports') || catLower.contains('spor') || titleLower.contains('maç')) {
        return 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop';
      } else if (catLower.contains('film') || catLower.contains('sinema')) {
        return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1200&auto=format&fit=crop';
      }
      return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1200&auto=format&fit=crop';
    }

    return trimmedUrl;

  }

  final String atmosphere;
  final bool isPopular;

  factory EventModel.fromMap(Map<String, dynamic> map) => EventModel.fromJson(map);

  factory EventModel.fromJson(Map<String, dynamic> json) {
    try {
      return EventModel(
        id: json['id']?.toString() ?? UniqueKey().toString(),
        title: json['title']?.toString() ?? 'İsimsiz Etkinlik',
        category: json['type']?.toString() ?? json['category']?.toString() ?? 'Genel',
        location: json['city'] != null && json['venue'] != null 
            ? '${json['venue']}, ${json['city']}' 
            : json['venue']?.toString() ?? json['city']?.toString() ?? json['location']?.toString() ?? 'Bilinmiyor',
        dateTime: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
        description: json['description']?.toString() ?? '',
        imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
        latitude: json['lat'] != null ? double.tryParse(json['lat'].toString()) : (json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null),
        longitude: json['lng'] != null ? double.tryParse(json['lng'].toString()) : (json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null),
        ticketUrl: json['ticket_url']?.toString() ?? json['ticketUrl']?.toString() ?? json['url']?.toString(),
        ticketProvider: json['ticket_provider']?.toString() ?? json['ticketProvider']?.toString() ?? json['provider']?.toString(),
        isPopular: json['tag']?.toString().toLowerCase().contains('popüler') ?? false,
        atmosphere: json['tag']?.toString() ?? 'Canlı',
      );
    } catch (e) {
      debugPrint('EventModel fromJson error: $e');
      rethrow;
    }
  }

  static String _cleanUrl(String rawUrl) {
    String clean = rawUrl.trim();

    // 1. Ticketmaster API affiliate takip linklerinden (evyy.net) doğrudan Biletix bilet satın alma URL'sini (performance/...) çıkar
    if (clean.contains('evyy.net') || clean.contains('u=http') || clean.contains('u=https')) {
      try {
        final uri = Uri.parse(clean);
        final targetParam = uri.queryParameters['u'] ?? uri.queryParameters['url'] ?? uri.queryParameters['target'];
        if (targetParam != null && targetParam.isNotEmpty) {
          clean = Uri.decodeComponent(targetParam);
        }
      } catch (_) {
        final match = RegExp(r'[?&]u=(https?%3A%2F%2F[^&]+|https?://[^&]+)').firstMatch(clean);
        if (match != null) {
          clean = Uri.decodeComponent(match.group(1)!);
        }
      }
    }

    clean = clean.replaceAll(RegExp(r'[.,;:\)"\u0027\]>]+$'), '');
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    return clean;
  }

  String get effectiveTicketUrl {
    // 1. Doğrudan ticketUrl tanımlıysa ve geçerliyse
    if (ticketUrl != null && ticketUrl!.trim().isNotEmpty) {
      String clean = _cleanUrl(ticketUrl!);
      final lClean = clean.toLowerCase();
      
      final isTicketmasterUs = lClean.contains('ticketmaster.com') || lClean.contains('evyy.net');
      final isMockBroken = lClean.contains('5zemx');

      if (!isTicketmasterUs && !isMockBroken && clean.length > 25) {
        return clean;
      }
    }

    // 2. Açıklama metninde yer alan Biletinial / Biletix / Bubilet doğrudan etkinlik linkini bul
    final biletinialMatch = RegExp(r'https?://(?:www\.)?biletinial\.com/tr-tr/(?:muzik|tiyatro|stand-up|festival|opera-ve-bale|sinema|etkinlik)/[^\s\)\",]+', caseSensitive: false).firstMatch(description);
    if (biletinialMatch != null) {
      return _cleanUrl(biletinialMatch.group(0)!);
    }

    final genericBiletinial = RegExp(r'https?://(?:www\.)?biletinial\.com/tr-tr/[^\s\)\",]+', caseSensitive: false).firstMatch(description);
    if (genericBiletinial != null) {
      return _cleanUrl(genericBiletinial.group(0)!);
    }

    final biletixMatch = RegExp(r'https?://(?:www\.)?biletix\.com/performance/[^\s\)\",]+', caseSensitive: false).firstMatch(description);
    if (biletixMatch != null) {
      return _cleanUrl(biletixMatch.group(0)!);
    }

    final genericMatches = RegExp(r'https?://[^\s\)\",]+').allMatches(description);
    for (var m in genericMatches) {
      final u = _cleanUrl(m.group(0)!);
      final lu = u.toLowerCase();
      if (!lu.contains('unsplash.com') &&
          !lu.contains('merlincdn.net') &&
          !lu.contains('supabase.co') &&
          !lu.contains('5zemx') &&
          !lu.contains('ticketmaster.com') &&
          !lu.contains('evyy.net')) {
        return u;
      }
    }

    // 3. Özel linki bulunmayan etkinlikler için Biletinial üzerinde doğrudan bu etkinliği arat (Asla boş ana sayfaya yönlendirmez!)
    final cleanTitle = title.replaceAll(RegExp(r'[\(\)\[\]\-]'), ' ').trim();
    return 'https://biletinial.com/tr-tr/search?q=${Uri.encodeComponent(cleanTitle)}';
  }

  /// Ekranda gösterilecek temiz açıklama (Bilet satış linki metinlerini açıklamadan temizler)
  String get cleanDescription {
    String desc = description;
    desc = desc.replaceAll(RegExp(r'Bilet\s+Satış\s+Sayfası:\s*https?://[^\s]+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'https?://[^\s]+'), '');
    return desc.trim();
  }

  double? getDistanceInKm(double userLat, double userLng) {
    if (latitude == null || longitude == null) return null;
    try {
      final distanceInMeters = Geolocator.distanceBetween(userLat, userLng, latitude!, longitude!);
      return (distanceInMeters / 1000.0);
    } catch (_) {
      return null;
    }
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? category,
    String? location,
    DateTime? dateTime,
    String? description,
    String? imageUrl,
    List<UserModel>? attendees,
    double? latitude,
    double? longitude,
    String? ticketUrl,
    String? ticketProvider,
    bool? isActive,
    String? atmosphere,
    bool? isPopular,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      attendees: attendees ?? this.attendees,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      ticketProvider: ticketProvider ?? this.ticketProvider,
      isActive: isActive ?? this.isActive,
      atmosphere: atmosphere ?? this.atmosphere,
      isPopular: isPopular ?? this.isPopular,
    );
  }
}
