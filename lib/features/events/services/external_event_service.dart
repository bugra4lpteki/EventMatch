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

            // Görsel tespiti (Biletix Resmi Etkinlik Afişini Güvenli Seçme)
            String imageUrl = '';
            if (item['images'] != null && item['images'] is List) {
              final rawList = item['images'] as List;
              if (rawList.isNotEmpty) {
                // 1. Öncelik: 16:9 Geniş Resmi Etkinlik Afişi
                for (var img in rawList) {
                  if (img is Map && (img['ratio']?.toString() == '16_9' || img['url']?.toString().contains('16_9') == true)) {
                    final u = img['url']?.toString();
                    if (u != null && u.startsWith('http')) {
                      imageUrl = u;
                      break;
                    }
                  }
                }
                // 2. Öncelik: Herhangi bir HD resmi afiş URL'i
                if (imageUrl.isEmpty) {
                  for (var img in rawList) {
                    if (img is Map) {
                      final u = img['url']?.toString();
                      if (u != null && u.startsWith('http')) {
                        imageUrl = u;
                        break;
                      }
                    }
                  }
                }
              }
            }

            if (imageUrl.isEmpty) {
              imageUrl = 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745';
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
        return EventModel(
          id: 'biletix_${item['id'] ?? item['code'] ?? UniqueKey().toString()}',
          title: item['name'] ?? item['title'] ?? 'Biletix Etkinliği',
          category: item['categoryName'] ?? item['type'] ?? 'Konser',
          location: '${item['venueName'] ?? 'Mekan'}, ${item['cityName'] ?? 'İstanbul'}',
          dateTime: item['date'] != null 
              ? DateTime.tryParse(item['date']) ?? DateTime.now() 
              : DateTime.now(),
          description: item['summary'] ?? item['description'] ?? 'Biletix üzerinden sunulan etkinlik.',
          imageUrl: item['imageUrl'] ?? item['image'] ?? 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745',
          latitude: item['latitude'] != null ? double.tryParse(item['latitude'].toString()) : null,
          longitude: item['longitude'] != null ? double.tryParse(item['longitude'].toString()) : null,
          ticketUrl: item['url'] ?? item['ticketUrl'] ?? 'https://www.biletix.com',
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
}
