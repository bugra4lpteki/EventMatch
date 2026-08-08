import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/api_keys.dart';
import '../models/event_model.dart';

/// Biletix (Ticketmaster), Bubilet, Biletinial ve diğer biletleme servisleri için API entegrasyonu servisi.
class ExternalEventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 🌐 Ticketmaster / Biletix Canlı API'sinden Türkiye Etkinliklerini Çekme
  Future<List<EventModel>> fetchLiveTicketmasterEvents({String countryCode = 'TR'}) async {
    final apiKey = ApiKeys.ticketmasterApiKey;
    final url = Uri.parse(
      'https://app.ticketmaster.com/discovery/v2/events.json?countryCode=$countryCode&apikey=$apiKey&size=20',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embedded = data['_embedded'];
        if (embedded == null || embedded['events'] == null) {
          debugPrint('Ticketmaster API: Etkinlik bulunamadı.');
          return [];
        }

        final List<dynamic> eventsJson = embedded['events'];
        final List<EventModel> eventsList = [];

        for (var item in eventsJson) {
          try {
            final id = 'biletix_${item['id'] ?? UniqueKey().toString()}';
            final title = item['name'] ?? 'Biletix Etkinliği';
            final ticketUrl = item['url'] ?? 'https://www.biletix.com';

            // Kategori tespiti
            String category = 'Genel';
            if (item['classifications'] != null && (item['classifications'] as List).isNotEmpty) {
              final segment = item['classifications'][0]['segment'];
              if (segment != null && segment['name'] != null) {
                category = segment['name'];
              }
            }

            // Mekan & Şehir bilgisi
            String venueName = 'Mekan';
            String cityName = 'İstanbul';
            double? lat;
            double? lng;

            if (item['_embedded'] != null && item['_embedded']['venues'] != null && (item['_embedded']['venues'] as List).isNotEmpty) {
              final venue = item['_embedded']['venues'][0];
              venueName = venue['name'] ?? venueName;
              if (venue['city'] != null) {
                cityName = venue['city']['name'] ?? cityName;
              }
              if (venue['location'] != null) {
                lat = double.tryParse(venue['location']['latitude']?.toString() ?? '');
                lng = double.tryParse(venue['location']['longitude']?.toString() ?? '');
              }
            }

            // Tarih bilgisi
            DateTime dateTime = DateTime.now();
            if (item['dates'] != null && item['dates']['start'] != null) {
              final start = item['dates']['start'];
              if (start['dateTime'] != null) {
                dateTime = DateTime.tryParse(start['dateTime']) ?? dateTime;
              } else if (start['localDate'] != null) {
                dateTime = DateTime.tryParse(start['localDate']) ?? dateTime;
              }
            }

            // 1. ÖNCELİK: Biletix İnternet Sitesinin Orijinal Afiş Resmi (CORS Engelini Aşan Proxy)
            String imageUrl = '';
            if (ticketUrl.contains('biletix.com')) {
              final match = RegExp(r'/performance/([A-Za-z0-9]+)').firstMatch(ticketUrl);
              if (match != null) {
                final code = match.group(1);
                if (code != null && code.isNotEmpty) {
                  imageUrl = 'https://images.weserv.nl/?url=www.biletix.com/static/images/live/event/eventimages/$code.png';
                }
              }
            }

            // 2. ÖNCELİK: API Afiş Listesindeki HD Görsel
            if (imageUrl.isEmpty && item['images'] != null && item['images'] is List) {
              final rawList = (item['images'] as List).whereType<Map>().toList();
              if (rawList.isNotEmpty) {
                final banners169 = rawList.where((img) {
                  final ratio = img['ratio']?.toString() ?? '';
                  final u = img['url']?.toString() ?? '';
                  return ratio == '16_9' || u.contains('16_9') || u.contains('TABLET_LANDSCAPE');
                }).toList();

                if (banners169.isNotEmpty) {
                  banners169.sort((a, b) {
                    int wA = int.tryParse(a['width']?.toString() ?? '0') ?? 0;
                    int wB = int.tryParse(b['width']?.toString() ?? '0') ?? 0;
                    return wB.compareTo(wA);
                  });
                  imageUrl = banners169.first['url']?.toString() ?? '';
                }

                if (imageUrl.isEmpty) {
                  rawList.sort((a, b) {
                    int wA = int.tryParse(a['width']?.toString() ?? '0') ?? 0;
                    int wB = int.tryParse(b['width']?.toString() ?? '0') ?? 0;
                    return wB.compareTo(wA);
                  });
                  imageUrl = rawList.first['url']?.toString() ?? '';
                }
              }
            }

            if (imageUrl.isEmpty) {
              imageUrl = _getCategoryFallbackImage(category, title);
            }

            // Açıklama
            final description = item['pleaseNote'] ?? item['info'] ?? '$title etkinliği Biletix güvencesiyle karşınızda.';

            eventsList.add(EventModel(
              id: id,
              title: title,
              category: category,
              location: '$venueName, $cityName',
              dateTime: dateTime,
              description: description,
              imageUrl: imageUrl,
              latitude: lat,
              longitude: lng,
              ticketUrl: ticketUrl,
              ticketProvider: 'Biletix',
              atmosphere: '🔥 Popüler',
              isPopular: true,
            ));
          } catch (e) {
            debugPrint('Biletix tekil etkinlik parse hatası: $e');
          }
        }

        debugPrint('✅ Ticketmaster/Biletix API: ${eventsList.length} canlı etkinlik çekildi.');
        return eventsList;
      } else {
        debugPrint('❌ Ticketmaster API Hatası: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Ticketmaster Istek Hatası: $e');
      return [];
    }
  }

  /// 🎫 Biletix API Verilerini Manuel Ayrıştırma
  List<EventModel> parseBiletixEvents(String rawJson) {
    try {
      final List<dynamic> list = jsonDecode(rawJson);
      return list.map((item) {
        final ticketUrl = item['url'] ?? item['ticketUrl'] ?? 'https://www.biletix.com';
        String imageUrl = '';
        final match = RegExp(r'/performance/([A-Za-z0-9]+)').firstMatch(ticketUrl);
        if (match != null) {
          final code = match.group(1);
          if (code != null && code.isNotEmpty) {
            imageUrl = 'https://images.weserv.nl/?url=www.biletix.com/static/images/live/event/eventimages/$code.png';
          }
        }
        if (imageUrl.isEmpty) {
          imageUrl = item['imageUrl'] ?? item['image'] ?? 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745';
        }

        return EventModel(
          id: 'biletix_${item['id'] ?? item['code'] ?? UniqueKey().toString()}',
          title: item['name'] ?? item['title'] ?? 'Biletix Etkinliği',
          category: item['categoryName'] ?? item['type'] ?? 'Konser',
          location: '${item['venueName'] ?? 'Mekan'}, ${item['cityName'] ?? 'İstanbul'}',
          dateTime: item['date'] != null 
              ? DateTime.tryParse(item['date']) ?? DateTime.now() 
              : DateTime.now(),
          description: item['summary'] ?? item['description'] ?? 'Biletix üzerinden sunulan etkinlik.',
          imageUrl: imageUrl,
          latitude: item['latitude'] != null ? double.tryParse(item['latitude'].toString()) : null,
          longitude: item['longitude'] != null ? double.tryParse(item['longitude'].toString()) : null,
          ticketUrl: ticketUrl,
          ticketProvider: 'Biletix',
          atmosphere: '🔥 Popüler',
          isPopular: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Biletix parse hatası: $e');
      return [];
    }
  }

  /// 🎟 Bubilet API Verilerini Ayrıştırma
  List<EventModel> parseBubiletEvents(String rawJson) {
    try {
      final List<dynamic> list = jsonDecode(rawJson);
      return list.map((item) {
        return EventModel(
          id: 'bubilet_${item['id'] ?? UniqueKey().toString()}',
          title: item['title'] ?? item['eventName'] ?? 'Bubilet Etkinliği',
          category: item['category'] ?? 'Tiyatro',
          location: '${item['venue'] ?? 'Mekan'}, ${item['city'] ?? 'İstanbul'}',
          dateTime: item['startDate'] != null 
              ? DateTime.tryParse(item['startDate']) ?? DateTime.now() 
              : DateTime.now(),
          description: item['details'] ?? item['description'] ?? 'Bubilet üzerinden indirimli bilet imkanı.',
          imageUrl: item['posterUrl'] ?? item['image'] ?? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba',
          latitude: item['lat'] != null ? double.tryParse(item['lat'].toString()) : null,
          longitude: item['lng'] != null ? double.tryParse(item['lng'].toString()) : null,
          ticketUrl: item['link'] ?? item['buyUrl'] ?? 'https://www.bubilet.com.tr',
          ticketProvider: 'Bubilet',
          atmosphere: '✨ Fırsat Etkinliği',
          isPopular: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Bubilet parse hatası: $e');
      return [];
    }
  }

  /// 🎭 Biletinial API Verilerini Ayrıştırma
  List<EventModel> parseBiletinialEvents(String rawJson) {
    try {
      final List<dynamic> list = jsonDecode(rawJson);
      return list.map((item) {
        return EventModel(
          id: 'biletinial_${item['Id'] ?? item['id'] ?? UniqueKey().toString()}',
          title: item['Name'] ?? item['title'] ?? 'Biletinial Etkinliği',
          category: item['TypeName'] ?? item['category'] ?? 'Sinema & Tiyatro',
          location: '${item['HallName'] ?? item['venue'] ?? 'Mekan'}, ${item['CityName'] ?? 'İstanbul'}',
          dateTime: item['EventDate'] != null 
              ? DateTime.tryParse(item['EventDate']) ?? DateTime.now() 
              : DateTime.now(),
          description: item['Content'] ?? item['description'] ?? 'Biletinial etkinliği.',
          imageUrl: item['PictureUrl'] ?? item['imageUrl'] ?? 'https://images.unsplash.com/photo-1540575467063-178a50c2df87',
          latitude: item['Lat'] != null ? double.tryParse(item['Lat'].toString()) : null,
          longitude: item['Lng'] != null ? double.tryParse(item['Lng'].toString()) : null,
          ticketUrl: item['DetailUrl'] ?? item['ticketUrl'] ?? 'https://biletinial.com',
          ticketProvider: 'Biletinial',
          atmosphere: '🎭 Sanat',
          isPopular: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Biletinial parse hatası: $e');
      return [];
    }
  }

  /// Çekilen Etkinlikleri Supabase Veritabanına Kaydetme
  Future<void> syncEventsToSupabase(List<EventModel> events) async {
    try {
      for (var event in events) {
        final payload = {
          'title': event.title,
          'type': event.category,
          'venue': event.location.split(',').first,
          'city': event.location.contains(',') ? event.location.split(',').last.trim() : 'İstanbul',
          'date': event.dateTime.toIso8601String(),
          'description': event.description,
          'image_url': event.imageUrl,
          'lat': event.latitude,
          'lng': event.longitude,
          'tag': event.atmosphere,
          'ticket_url': event.ticketUrl,
          'ticket_provider': event.ticketProvider,
        };

        await _supabase.from('events').insert(payload);
      }
      debugPrint('✅ ${events.length} adet etkinlik Supabase veritabanına aktarıldı.');
    } catch (e) {
      debugPrint('❌ Supabase senkronizasyon hatası: $e');
    }
  }

  /// 🌐 Biletix Web Sayfasından (biletix.com/performance/...) Orijinal og:image Afiş URL'sini Canlı Çekme
  static Future<String?> fetchBiletixSiteImage(String biletixUrl) async {
    try {
      if (!biletixUrl.contains('biletix.com')) return null;

      final response = await http.get(
        Uri.parse(biletixUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final html = response.body;

        // 1. og:image / twitter:image Meta Etiketlerini Yakalama
        final ogMatch = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
                        RegExp(r'<meta\s+name="twitter:image"\s+content="([^"]+)"', caseSensitive: false).firstMatch(html);
        if (ogMatch != null) {
          final imgUrl = ogMatch.group(1);
          if (imgUrl != null && imgUrl.startsWith('http')) {
            debugPrint('[BiletixScraper] 🖼️ Biletix Orijinal Afiş Bulundu: $imgUrl');
            return imgUrl;
          }
        }

        // 2. Biletix CDN Statik Resim Adresi
        final staticMatch = RegExp(r'https://www\.biletix\.com/static/images/live/event/eventimages/[^">\s]+').firstMatch(html);
        if (staticMatch != null) {
          return staticMatch.group(0);
        }
      }
    } catch (e) {
      debugPrint('[BiletixScraper] Görsel çekme hatası ($biletixUrl): $e');
    }
    return null;
  }

  /// Katategoriye Göre Akıllı Görsel Belirleyici (Stand Up, Tiyatro, Konser, Spor vb.)
  static String _getCategoryFallbackImage(String category, String title) {
    final catLower = category.toLowerCase();
    final titleLower = title.toLowerCase();

    if (catLower.contains('theatre') || catLower.contains('tiyatro') || catLower.contains('arts') || titleLower.contains('stand up') || titleLower.contains('gösteri')) {
      return 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?q=80&w=1200&auto=format&fit=crop';
    } else if (catLower.contains('sports') || catLower.contains('spor') || titleLower.contains('maç')) {
      return 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop';
    } else if (catLower.contains('film') || catLower.contains('sinema')) {
      return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1200&auto=format&fit=crop';
    } else if (catLower.contains('fest') || titleLower.contains('fest')) {
      return 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?q=80&w=1200&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1200&auto=format&fit=crop';
  }
}
