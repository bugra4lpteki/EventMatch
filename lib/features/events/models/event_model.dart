import 'package:flutter/foundation.dart';
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
    required this.imageUrl,
    this.latitude,
    this.longitude,
    this.ticketUrl,
    this.ticketProvider,
    this.isActive = true,
    this.atmosphere = 'Sakin',
    this.isPopular = false,
    List<UserModel>? attendees,
  }) : attendees = attendees ?? [];

  final String atmosphere;
  final bool isPopular;

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
    // 1. Doğrudan Biletix / Bubilet / Biletinial bilet satın alma linki varsa (performance/ veya etkinlik/ satın alma sayfası) direkt kullan
    if (ticketUrl != null && ticketUrl!.trim().isNotEmpty) {
      String clean = _cleanUrl(ticketUrl!);
      final lClean = clean.toLowerCase();
      
      final isTicketmasterUs = lClean.contains('ticketmaster.com') || lClean.contains('evyy.net');
      final isMockBroken = lClean.contains('5zemx');

      if (!isTicketmasterUs && !isMockBroken) {
        return clean;
      }
    }

    // 2. Açıklama metninde yer alan bilet satın alma linkini kontrol et
    if (description.contains('http')) {
      final match = RegExp(r'https?://[^\s]+').firstMatch(description);
      if (match != null) {
        String m = _cleanUrl(match.group(0)!);
        final lMatch = m.toLowerCase();
        if (!lMatch.contains('5zemx') && 
            !lMatch.contains('ticketmaster.com') && 
            !lMatch.contains('evyy.net')) {
          return m;
        }
      }
    }

    // 3. Özel linki bulunmayan etkinlikler için doğrudan Biletix / bilet platformlarının bilet alma sayfalarını aç (Google KESİNLİKLE YOK)
    String providerName = (ticketProvider != null && ticketProvider!.trim().isNotEmpty) ? ticketProvider!.trim() : '';
    
    if (providerName.toLowerCase().contains('bubilet')) {
      return 'https://www.bubilet.com.tr';
    } else if (providerName.toLowerCase().contains('biletinial')) {
      return 'https://biletinial.com';
    } else if (providerName.toLowerCase().contains('passo')) {
      return 'https://www.passo.com.tr';
    } else {
      final catLower = category.toLowerCase();
      if (catLower.contains('konser') || catLower.contains('müzik') || catLower.contains('music')) {
        return 'https://www.biletix.com/kategori/KONSER/TURKIYE/tr';
      } else if (catLower.contains('tiyatro') || catLower.contains('sahne') || catLower.contains('arts')) {
        return 'https://www.biletix.com/kategori/TIYATRO/TURKIYE/tr';
      } else if (catLower.contains('spor') || catLower.contains('sports')) {
        return 'https://www.biletix.com/kategori/SPOR/TURKIYE/tr';
      }
      return 'https://www.biletix.com/etkinlikler/TURKIYE/tr';
    }
  }

  /// Ekranda gösterilecek temiz açıklama (Bilet satış linki metinlerini açıklamadan temizler)
  String get cleanDescription {
    String desc = description;
    desc = desc.replaceAll(RegExp(r'Bilet\s+Satış\s+Sayfası:\s*https?://[^\s]+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'https?://[^\s]+'), '');
    return desc.trim();
  }
}
