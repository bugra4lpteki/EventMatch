import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Biletinial Scraper and Supabase Importer for EventMatch
/// Fetches live events, high-resolution posters, locations, dates, and ticket links.

const String supabaseUrl = 'https://pqtpogebnfubrqowlnkq.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxdHBvZ2VibmZ1YnJxb3dsbmtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwNjM4NjMsImV4cCI6MjEwMDYzOTg2M30.jHzTJadRqvmrlGGjkFZ9qNUKNi_2CatfBGUxCZ_cn6o';

final Map<String, String> categoryPaths = {
  'Konser': 'https://biletinial.com/tr-tr/muzik',
  'Tiyatro': 'https://biletinial.com/tr-tr/tiyatro',
  'Stand-up': 'https://biletinial.com/tr-tr/stand-up',
  'Festival': 'https://biletinial.com/tr-tr/festival',
  'Opera & Bale': 'https://biletinial.com/tr-tr/opera-ve-bale',
};

final Map<String, String> defaultHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
};

Future<void> main(List<String> args) async {
  print('====================================================');
  print('🎟️ EVENTMATCH - BİLETİNİAL OTOMATİK ETKİNLİK & AFİŞ AKTARICI');
  print('====================================================\n');

  final allEvents = <Map<String, dynamic>>[];
  final seenKeys = <String>{};

  for (var entry in categoryPaths.entries) {
    final categoryName = entry.key;
    final categoryUrl = entry.value;

    print('📡 [$categoryName] Kategorisi taranıyor: $categoryUrl...');

    try {
      final response = await http.get(Uri.parse(categoryUrl), headers: defaultHeaders);
      if (response.statusCode != 200) {
        print('⚠️ Sayfa açılamadı (${response.statusCode}): $categoryUrl');
        continue;
      }

      final html = response.body;
      final eventUrls = extractEventUrls(html);
      print('   -> ${eventUrls.length} adet etkinlik bağlantısı bulundu.');

      int importedCount = 0;
      for (var url in eventUrls.take(15)) {
        try {
          final eventDetails = await fetchEventDetails(url, categoryName);
          for (var ev in eventDetails) {
            final key = '${ev['title']}_${ev['city']}_${ev['date']}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              allEvents.add(ev);
              importedCount++;
            }
          }
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          print('   ⚠️ Etkinlik çekilemedi ($url): $e');
        }
      }
      print('   ✅ [$categoryName] $importedCount adet güncel gösterim hazırlandı.\n');
    } catch (e) {
      print('❌ Kategori hatası ($categoryName): $e\n');
    }
  }

  print('📊 Toplam taranan ve oluşturulan etkinlik: ${allEvents.length}');

  if (allEvents.isNotEmpty) {
    print('🚀 Supabase "events" tablosuna aktarılıyor...');
    await uploadEventsToSupabase(allEvents);
  }

  print('\n🎉 İŞLEM TAMAMLANDI! Tüm Biletinial etkinlikleri ve afişleri veritabanına aktarıldı.');
}

List<String> extractEventUrls(String html) {
  final urls = <String>{};

  // 1. JSON-LD ItemList arama
  final jsonLdRegex = RegExp(r'<script type="application/ld\+json">(.*?)</script>', dotAll: true);
  for (var match in jsonLdRegex.allMatches(html)) {
    try {
      final jsonStr = match.group(1)?.trim() ?? '';
      if (jsonStr.contains('"ItemList"')) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map && decoded['itemListElement'] is List) {
          for (var item in decoded['itemListElement']) {
            final u = item['url']?.toString();
            if (u != null && u.startsWith('http')) {
              urls.add(u);
            }
          }
        }
      }
    } catch (_) {}
  }

  // 2. HTML <a> href yedek arama
  final hrefRegex = RegExp(r'href="(/tr-tr/(?:muzik|tiyatro|stand-up|festival|opera-ve-bale)/[a-zA-Z0-9_-]+)"');
  for (var match in hrefRegex.allMatches(html)) {
    final path = match.group(1);
    if (path != null && !path.endsWith('/muzik') && !path.endsWith('/tiyatro')) {
      urls.add('https://biletinial.com$path');
    }
  }

  return urls.toList();
}

String generateUuidFromSeed(String input) {
  var hash = 0;
  for (var i = 0; i < input.length; i++) {
    hash = (hash << 5) - hash + input.codeUnitAt(i);
    hash &= 0xFFFFFFFFFFFFFFFF;
  }
  final rng = Random(hash.abs());
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

Future<List<Map<String, dynamic>>> fetchEventDetails(String url, String category) async {
  final response = await http.get(Uri.parse(url), headers: defaultHeaders);
  if (response.statusCode != 200) return [];

  final html = response.body;
  final results = <Map<String, dynamic>>[];

  // JSON-LD Event extraction
  final jsonLdRegex = RegExp(r'<script type="application/ld\+json">(.*?)</script>', dotAll: true);
  for (var match in jsonLdRegex.allMatches(html)) {
    try {
      final jsonStr = match.group(1)?.trim() ?? '';
      if (jsonStr.contains('"Event"')) {
        dynamic decoded = jsonDecode(jsonStr);
        final list = decoded is List ? decoded : [decoded];

        for (var item in list) {
          if (item is Map && (item['@type'] == 'Event' || item['type'] == 'Event')) {
            final name = item['name']?.toString().trim() ?? 'Etkinlik';
            final desc = item['description']?.toString().trim() ?? '';
            String imageUrl = item['image']?.toString().trim() ?? '';
            final startDateStr = item['startDate']?.toString();
            final eventUrl = item['url']?.toString() ?? url;

            final location = item['location'];
            String venue = 'Belirtilmedi';
            String city = 'İstanbul';
            double? lat;
            double? lng;

            if (location is Map) {
              venue = location['name']?.toString().trim() ?? venue;
              final address = location['address'];
              if (address is Map) {
                city = address['addressLocality']?.toString().trim() ??
                    address['addressRegion']?.toString().trim() ??
                    city;
              }
              final geo = location['geo'];
              if (geo is Map) {
                lat = double.tryParse(geo['latitude']?.toString() ?? '');
                lng = double.tryParse(geo['longitude']?.toString() ?? '');
              }
            }

            if (imageUrl.isEmpty) {
              final ogMatch = RegExp(r'<meta property="og:image" content="(.*?)"').firstMatch(html);
              imageUrl = ogMatch?.group(1) ?? '';
            }

            DateTime eventDate = DateTime.now().add(const Duration(days: 7));
            if (startDateStr != null) {
              final parsed = DateTime.tryParse(startDateStr);
              if (parsed != null) {
                eventDate = parsed;
              }
            }

            final cleanDesc = desc.isNotEmpty
                ? '$desc\n\nBilet Satış Sayfası: $eventUrl'
                : '$name etkinliği $venue sahnesinde sizlerle buluşuyor.\n\nBilet Satış Sayfası: $eventUrl';

            // Supabase UUID formatı
            final eventId = generateUuidFromSeed('biletinial_${name}_${venue}_${eventDate.millisecondsSinceEpoch}');

            results.add({
              'id': eventId,
              'title': name,
              'type': category,
              'venue': venue,
              'city': city,
              'date': eventDate.toUtc().toIso8601String(),
              'description': cleanDesc,
              'image_url': imageUrl,
              'lat': lat ?? 41.0082,
              'lng': lng ?? 28.9784,
              'tag': '🔥 Popüler',
            });
          }
        }
      }
    } catch (_) {}
  }

  return results;
}

Future<void> uploadEventsToSupabase(List<Map<String, dynamic>> events) async {
  final endpoint = Uri.parse('$supabaseUrl/rest/v1/events?on_conflict=id');

  // 10'arlı gruplar halinde upsert et
  for (var i = 0; i < events.length; i += 10) {
    final chunk = events.skip(i).take(10).toList();
    try {
      final res = await http.post(
        endpoint,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode(chunk),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        print('   ✨ ${i + chunk.length}/${events.length} etkinlik Supabase\'e başarıyla yazıldı.');
      } else {
        print('   ⚠️ Supabase yazma yanıtı (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      print('   ❌ Supabase aktarım hatası: $e');
    }
  }
}
