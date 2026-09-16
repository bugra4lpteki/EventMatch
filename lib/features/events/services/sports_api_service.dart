import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_keys.dart';
import '../models/event_model.dart';

/// ⚽ Futbol Müsabakaları Canlı Servisi
/// 1. Football-Data.org API v4 (X-Auth-Token ile Şampiyonlar Ligi, Premier Lig, La Liga, Serie A, Bundesliga vb.)
/// 2. ESPN Live Sports API (Trendyol Süper Lig canlı fikstürleri, gerçek stadyum ve başlama saatleri)
/// 3. Yalnızca Futbol müsabakaları desteklenir (Basketbol, Voleybol, Tenis kaldırılmıştır)
/// ÖNEMLİ KURAL: Bu servisten dönen tüm müsabakalarda bilet yönlendirmesi (ticketUrl, ticketProvider) KESİNLİKLE OLMAZ.
class SportsApiService {
  static const String _footballDataBaseUrl = 'https://api.football-data.org/v4';

  static const String _cacheKey = 'eventmatch_football_data_fixtures_cache_v7';
  static const String _cacheTimeKey = 'eventmatch_football_data_fixtures_time_v7';

  // Bilinen stadyumlar ve hassas GPS koordinatları haritası (Türkiye & Avrupa)
  static const Map<String, Map<String, dynamic>> stadiumCoordinates = {
    // Türkiye - Süper Lig Stadyumları
    'rams': {'name': 'RAMS Park', 'city': 'İstanbul', 'lat': 41.1034, 'lng': 28.9912},
    'ülker stadyumu': {'name': 'Ülker Stadyumu Şükrü Saracoğlu', 'city': 'İstanbul', 'lat': 40.9877, 'lng': 29.0369},
    'tüpraş': {'name': 'Tüpraş Stadyumu', 'city': 'İstanbul', 'lat': 41.0391, 'lng': 28.9944},
    'papara': {'name': 'Papara Park', 'city': 'Trabzon', 'lat': 40.9781, 'lng': 39.6389},
    'başakşehir': {'name': 'Başakşehir Fatih Terim Stadyumu', 'city': 'İstanbul', 'lat': 41.1228, 'lng': 28.8094},
    'kasımpaşa': {'name': 'Recep Tayyip Erdoğan Stadyumu', 'city': 'İstanbul', 'lat': 41.0328, 'lng': 28.9719},
    'gürsel aksel': {'name': 'Gürsel Aksel Stadyumu', 'city': 'İzmir', 'lat': 38.3972, 'lng': 27.0858},
    'samsun': {'name': 'Samsun 19 Mayıs Stadyumu', 'city': 'Samsun', 'lat': 41.2581, 'lng': 36.4389},
    'antalya': {'name': 'Corendon Airlines Park', 'city': 'Antalya', 'lat': 36.8858, 'lng': 30.6692},
    'alanya': {'name': 'Alanya Gain Park Stadyumu', 'city': 'Antalya', 'lat': 36.5492, 'lng': 32.0461},
    'konya': {'name': 'Medaş Konya Büyükşehir Stadyumu', 'city': 'Konya', 'lat': 37.9547, 'lng': 32.4939},
    'sivas': {'name': 'BG Grup 4 Eylül Stadyumu', 'city': 'Sivas', 'lat': 39.7369, 'lng': 37.0175},
    'kayseri': {'name': 'RHG Enertürk Enerji Stadyumu', 'city': 'Kayseri', 'lat': 38.7428, 'lng': 35.4383},
    'gaziantep': {'name': 'Kalyon Stadyumu', 'city': 'Gaziantep', 'lat': 37.1189, 'lng': 37.3828},
    'adana': {'name': 'Yeni Adana Stadyumu', 'city': 'Adana', 'lat': 37.0542, 'lng': 35.3525},
    'rize': {'name': 'Çaykur Didi Stadyumu', 'city': 'Rize', 'lat': 41.0319, 'lng': 40.5489},
    'bursa': {'name': 'Yüzüncü Yıl Atatürk Stadyumu', 'city': 'Bursa', 'lat': 40.2078, 'lng': 29.0069},
    'kocaeli': {'name': 'Yıldız Entegre Kocaeli Stadyumu', 'city': 'Kocaeli', 'lat': 40.7656, 'lng': 29.9890},
    'ankara': {'name': 'Eryaman Stadyumu', 'city': 'Ankara', 'lat': 39.9839, 'lng': 32.6469},
    'diyarbakır': {'name': 'Diyarbakır Stadyumu', 'city': 'Diyarbakır', 'lat': 37.9144, 'lng': 40.2306},
    'erzurum': {'name': 'Kâzım Karabekir Stadyumu', 'city': 'Erzurum', 'lat': 39.9042, 'lng': 41.2678},
    'çorum': {'name': 'Çorum Şehir Stadyumu', 'city': 'Çorum', 'lat': 40.5506, 'lng': 34.9556},

    // İspanya (La Liga)
    'real madrid': {'name': 'Santiago Bernabéu', 'city': 'Madrid', 'lat': 40.4530, 'lng': -3.6883},
    'barcelona': {'name': 'Camp Nou (Montjuïc)', 'city': 'Barselona', 'lat': 41.3648, 'lng': 2.1556},
    'barça': {'name': 'Camp Nou (Montjuïc)', 'city': 'Barselona', 'lat': 41.3648, 'lng': 2.1556},
    'atlético': {'name': 'Cívitas Metropolitano', 'city': 'Madrid', 'lat': 40.4362, 'lng': -3.5995},
    'atleti': {'name': 'Cívitas Metropolitano', 'city': 'Madrid', 'lat': 40.4362, 'lng': -3.5995},
    'sevilla': {'name': 'Ramón Sánchez-Pizjuán', 'city': 'Sevilla', 'lat': 37.3840, 'lng': -5.9705},
    'valencia': {'name': 'Mestalla', 'city': 'Valencia', 'lat': 39.4746, 'lng': -0.3582},
    'athletic': {'name': 'San Mamés', 'city': 'Bilbao', 'lat': 43.2642, 'lng': -2.9493},
    'real sociedad': {'name': 'Reale Arena', 'city': 'San Sebastián', 'lat': 43.3014, 'lng': -1.9736},

    // İngiltere (Premier League)
    'arsenal': {'name': 'Emirates Stadium', 'city': 'Londra', 'lat': 51.5549, 'lng': -0.1084},
    'chelsea': {'name': 'Stamford Bridge', 'city': 'Londra', 'lat': 51.4816, 'lng': -0.1910},
    'liverpool': {'name': 'Anfield', 'city': 'Liverpool', 'lat': 53.4308, 'lng': -2.9608},
    'manchester city': {'name': 'Etihad Stadium', 'city': 'Manchester', 'lat': 53.4831, 'lng': -2.2004},
    'man city': {'name': 'Etihad Stadium', 'city': 'Manchester', 'lat': 53.4831, 'lng': -2.2004},
    'manchester united': {'name': 'Old Trafford', 'city': 'Manchester', 'lat': 53.4631, 'lng': -2.2913},
    'man united': {'name': 'Old Trafford', 'city': 'Manchester', 'lat': 53.4631, 'lng': -2.2913},
    'tottenham': {'name': 'Tottenham Hotspur Stadium', 'city': 'Londra', 'lat': 51.6042, 'lng': -0.0664},
    'newcastle': {'name': 'St. James\' Park', 'city': 'Newcastle', 'lat': 54.9755, 'lng': -1.6216},

    // İtalya (Serie A)
    'milan': {'name': 'San Siro (Giuseppe Meazza)', 'city': 'Milano', 'lat': 45.4781, 'lng': 9.1240},
    'inter': {'name': 'San Siro (Giuseppe Meazza)', 'city': 'Milano', 'lat': 45.4781, 'lng': 9.1240},
    'juventus': {'name': 'Allianz Stadium', 'city': 'Torino', 'lat': 45.1096, 'lng': 7.6413},
    'roma': {'name': 'Stadio Olimpico', 'city': 'Roma', 'lat': 41.9341, 'lng': 12.4547},
    'lazio': {'name': 'Stadio Olimpico', 'city': 'Roma', 'lat': 41.9341, 'lng': 12.4547},
    'napoli': {'name': 'Stadio Diego Armando Maradona', 'city': 'Napoli', 'lat': 40.8279, 'lng': 14.1930},

    // Almanya (Bundesliga)
    'bayern': {'name': 'Allianz Arena', 'city': 'Münih', 'lat': 48.2188, 'lng': 11.6247},
    'dortmund': {'name': 'Signal Iduna Park', 'city': 'Dortmund', 'lat': 51.4926, 'lng': 7.4519},
    'leverkusen': {'name': 'BayArena', 'city': 'Leverkusen', 'lat': 51.0382, 'lng': 7.0022},
    'leipzig': {'name': 'Red Bull Arena', 'city': 'Leipzig', 'lat': 51.3458, 'lng': 12.3644},

    // Fransa (Ligue 1)
    'psg': {'name': 'Parc des Princes', 'city': 'Paris', 'lat': 48.8414, 'lng': 2.2530},
    'marseille': {'name': 'Orange Vélodrome', 'city': 'Marsilya', 'lat': 43.2699, 'lng': 5.3959},

    // Portekiz
    'porto': {'name': 'Estádio do Dragão', 'city': 'Porto', 'lat': 41.1618, 'lng': -8.5836},
    'benfica': {'name': 'Estádio da Luz', 'city': 'Lizbon', 'lat': 38.7527, 'lng': -9.1847},
    'sporting': {'name': 'Estádio José Alvalade', 'city': 'Lizbon', 'lat': 38.7612, 'lng': -9.1607},
  };

  /// Takım adına göre stadyum anahtarı eşleme
  static String _resolveStadiumKey(String teamName) {
    final t = teamName.toLowerCase();

    // Türkiye
    if (t.contains('galatasaray')) return 'rams';
    if (t.contains('fenerbahçe') || t.contains('fenerbahce')) return 'ülker stadyumu';
    if (t.contains('beşiktaş') || t.contains('besiktas')) return 'tüpraş';
    if (t.contains('trabzon')) return 'papara';
    if (t.contains('başakşehir') || t.contains('basaksehir')) return 'başakşehir';
    if (t.contains('kasımpaşa') || t.contains('kasimpasa')) return 'kasımpaşa';
    if (t.contains('göztepe') || t.contains('goztepe')) return 'gürsel aksel';
    if (t.contains('samsun')) return 'samsun';
    if (t.contains('antalyaspor') || t.contains('antalya')) return 'antalya';
    if (t.contains('alanyaspor') || t.contains('alanya')) return 'alanya';
    if (t.contains('konyaspor') || t.contains('konya')) return 'konya';
    if (t.contains('sivasspor') || t.contains('sivas')) return 'sivas';
    if (t.contains('kayserispor') || t.contains('kayseri')) return 'kayseri';
    if (t.contains('gaziantep')) return 'gaziantep';
    if (t.contains('adana')) return 'adana';
    if (t.contains('rize')) return 'rize';
    if (t.contains('bursaspor') || t.contains('bursa')) return 'bursa';
    if (t.contains('kocaelispor') || t.contains('kocaeli')) return 'kocaeli';
    if (t.contains('eryaman') || t.contains('ankara')) return 'ankara';
    if (t.contains('diyarbakır') || t.contains('amed')) return 'diyarbakır';
    if (t.contains('erzurum')) return 'erzurum';
    if (t.contains('çorum') || t.contains('corum')) return 'çorum';

    // Avrupa
    if (t.contains('real madrid')) return 'real madrid';
    if (t.contains('barcelona') || t.contains('barça')) return 'barcelona';
    if (t.contains('atlético') || t.contains('atletico') || t.contains('atleti')) return 'atlético';
    if (t.contains('sevilla')) return 'sevilla';
    if (t.contains('valencia')) return 'valencia';
    if (t.contains('athletic')) return 'athletic';
    if (t.contains('sociedad')) return 'real sociedad';

    if (t.contains('arsenal')) return 'arsenal';
    if (t.contains('chelsea')) return 'chelsea';
    if (t.contains('liverpool')) return 'liverpool';
    if (t.contains('manchester city') || t.contains('man city')) return 'manchester city';
    if (t.contains('manchester united') || t.contains('man united')) return 'manchester united';
    if (t.contains('tottenham')) return 'tottenham';
    if (t.contains('newcastle')) return 'newcastle';

    if (t.contains('ac milan') || t == 'milan') return 'milan';
    if (t.contains('inter')) return 'inter';
    if (t.contains('juventus')) return 'juventus';
    if (t.contains('roma') && !t.contains('deportivo')) return 'roma';
    if (t.contains('lazio')) return 'lazio';
    if (t.contains('napoli')) return 'napoli';

    if (t.contains('bayern')) return 'bayern';
    if (t.contains('dortmund')) return 'dortmund';
    if (t.contains('leverkusen')) return 'leverkusen';
    if (t.contains('leipzig')) return 'leipzig';

    if (t.contains('psg') || t.contains('paris')) return 'psg';
    if (t.contains('marseille')) return 'marseille';

    if (t.contains('porto')) return 'porto';
    if (t.contains('benfica')) return 'benfica';
    if (t.contains('sporting')) return 'sporting';

    return '';
  }

  /// Takım adını düzgün Türkçe yazıma dönüştürür
  static String formatTeamName(String raw) {
    final t = raw.trim();
    final lower = t.toLowerCase();

    // Türk Takımları
    if (lower.contains('galatasaray')) return 'Galatasaray';
    if (lower.contains('fenerbahce') || lower.contains('fenerbahçe')) return 'Fenerbahçe';
    if (lower.contains('besiktas') || lower.contains('beşiktaş')) return 'Beşiktaş';
    if (lower.contains('trabzon')) return 'Trabzonspor';
    if (lower.contains('kasimpasa') || lower.contains('kasımpaşa')) return 'Kasımpaşa';
    if (lower.contains('basaksehir') || lower.contains('başakşehir')) return 'İstanbul Başakşehir';
    if (lower.contains('goztepe') || lower.contains('göztepe')) return 'Göztepe';
    if (lower.contains('eyup') || lower.contains('eyüp')) return 'Eyüpspor';
    if (lower.contains('konyaspor')) return 'Konyaspor';
    if (lower.contains('kocaelispor')) return 'Kocaelispor';
    if (lower.contains('gaziantep')) return 'Gaziantep FK';
    if (lower.contains('alanyaspor')) return 'Alanyaspor';
    if (lower.contains('samsun')) return 'Samsunspor';
    if (lower.contains('rize') || lower.contains('rizespor')) return 'Çaykur Rizespor';
    if (lower.contains('sivas')) return 'Sivasspor';
    if (lower.contains('kayseri')) return 'Kayserispor';
    if (lower.contains('antalya')) return 'Antalyaspor';
    if (lower.contains('adana')) return 'Adana Demirspor';
    if (lower.contains('amed')) return 'Amed SFK';
    if (lower.contains('erzurum')) return 'Erzurumspor FK';
    if (lower.contains('corum') || lower.contains('çorum')) return 'Çorum FK';
    if (lower.contains('genclerbirligi') || lower.contains('gençlerbirliği')) return 'Gençlerbirliği';

    // Uluslararası Takımlar
    if (lower.contains('barcelona') || lower == 'barça') return 'FC Barcelona';
    if (lower.contains('real madrid')) return 'Real Madrid';
    if (lower.contains('atlético') || lower.contains('atletico') || lower == 'atleti') return 'Atlético Madrid';
    if (lower.contains('bayern')) return 'Bayern München';
    if (lower.contains('dortmund')) return 'Borussia Dortmund';
    if (lower.contains('manchester city') || lower == 'man city') return 'Manchester City';
    if (lower.contains('manchester united') || lower == 'man united') return 'Manchester United';
    if (lower.contains('arsenal')) return 'Arsenal';
    if (lower.contains('liverpool')) return 'Liverpool';
    if (lower.contains('chelsea')) return 'Chelsea';
    if (lower.contains('paris') || lower == 'psg') return 'Paris Saint-Germain';
    if (lower.contains('inter')) return 'Inter Milano';
    if (lower.contains('milan') && !lower.contains('inter')) return 'AC Milan';
    if (lower.contains('juventus')) return 'Juventus';

    return t;
  }

  /// Belirli bir gün ve saat için gelecekteki en yakın maç tarihini hesaplar
  static DateTime makeUpcomingMatchDate(int targetWeekday, int hour, int minute) {
    final now = DateTime.now();
    int daysUntil = (targetWeekday - now.weekday) % 7;
    if (daysUntil == 0) {
      final candidate = DateTime(now.year, now.month, now.day, hour, minute);
      if (candidate.isAfter(now)) {
        return candidate;
      }
      daysUntil = 7;
    }
    final target = now.add(Duration(days: daysUntil));
    return DateTime(target.year, target.month, target.day, hour, minute);
  }

  static bool _isDerbyMatch(String home, String away) {
    final h = home.toLowerCase();
    final a = away.toLowerCase();

    // Türkiye Derbileri
    final bigTeams = ['galatasaray', 'fenerbahçe', 'beşiktaş', 'trabzonspor'];
    int trCount = 0;
    for (var b in bigTeams) {
      if (h.contains(b)) trCount++;
      if (a.contains(b)) trCount++;
    }
    if (trCount >= 2) return true;

    // Dünya Derbileri
    if ((h.contains('barcelona') || h.contains('barça')) && a.contains('madrid')) return true;
    if (h.contains('madrid') && (a.contains('barcelona') || a.contains('barça'))) return true;
    if (h.contains('milan') && a.contains('inter')) return true;
    if (h.contains('inter') && a.contains('milan')) return true;
    if (h.contains('arsenal') && a.contains('tottenham')) return true;
    if (h.contains('manchester') && a.contains('manchester')) return true;
    if (h.contains('liverpool') && (a.contains('manchester') || a.contains('everton'))) return true;
    if (h.contains('bayern') && a.contains('dortmund')) return true;
    if (h.contains('paris') && a.contains('marseille')) return true;

    return false;
  }

  /// Football-Data.org API İstek Başlıkları (X-Auth-Token)
  Map<String, String> _getFootballDataHeaders() {
    final token = ApiKeys.footballDataToken.trim();
    if (token.isEmpty) return {};
    return {
      'X-Auth-Token': token,
      'Accept': 'application/json',
    };
  }

  /// ⚽ Football-Data.org API v4 üzerinden Avrupa ve Dünya Ligleri Fikstürlerini Çeker
  /// (Şampiyonlar Ligi, Premier Lig, La Liga, Serie A, Bundesliga, Ligue 1 vb.)
  Future<List<EventModel>> fetchLiveFootballDataOrgMatches() async {
    final token = ApiKeys.footballDataToken.trim();
    if (token.isEmpty) {
      debugPrint('[SportsApiService] Football-Data.org API token tanımlı değil.');
      return [];
    }

    final List<EventModel> events = [];
    final now = DateTime.now();

    try {
      // Football-Data.org serbest planında dateFrom ve dateTo aralığı en fazla 10 gündür
      final dateFromStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final futureDate = now.add(const Duration(days: 9));
      final dateToStr = '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}';

      final url = Uri.parse('$_footballDataBaseUrl/matches?dateFrom=$dateFromStr&dateTo=$dateToStr');
      final res = await http.get(url, headers: _getFootballDataHeaders()).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawMatches = data['matches'] as List? ?? [];

        // Hız kısıtlayıcı başlık kontrolü
        final requestsAvailable = res.headers['x-requests-available-minute'];
        final resetSec = res.headers['x-requestcounter-reset'];
        debugPrint('[SportsApiService] ⚽ Football-Data.org: ${rawMatches.length} müsabaka alındı. (Kalan İstek: $requestsAvailable/dk, Sıfırlama: ${resetSec}s)');

        final Set<String> seenIds = {};

        for (var m in rawMatches) {
          try {
            final mId = m['id']?.toString();
            if (mId == null || seenIds.contains(mId)) continue;
            seenIds.add(mId);

            final homeTeam = m['homeTeam'];
            final awayTeam = m['awayTeam'];
            if (homeTeam == null || awayTeam == null) continue;

            final rawHome = homeTeam['shortName']?.toString() ?? homeTeam['name']?.toString() ?? 'Ev Sahibi';
            final rawAway = awayTeam['shortName']?.toString() ?? awayTeam['name']?.toString() ?? 'Deplasman';
            final homeName = formatTeamName(rawHome);
            final awayName = formatTeamName(rawAway);
            final matchTitle = '$homeName - $awayName';

            final dtStr = m['utcDate']?.toString();
            if (dtStr == null) continue;
            final matchDate = DateTime.tryParse(dtStr)?.toLocal();
            if (matchDate == null) continue;

            // 3 saatten daha eski tamamlanmış maçları atla
            if (matchDate.isBefore(now.subtract(const Duration(hours: 3)))) continue;

            final competition = m['competition'];
            final compName = competition?['name']?.toString() ?? 'Futbol Ligi';
            final area = m['area'];
            final areaName = area?['name']?.toString() ?? 'Avrupa';

            String venueName = 'Stadyum';
            String cityName = areaName;
            double? lat;
            double? lng;

            final stadiumKey = _resolveStadiumKey(homeName);
            if (stadiumCoordinates.containsKey(stadiumKey)) {
              final sInfo = stadiumCoordinates[stadiumKey]!;
              venueName = sInfo['name'];
              cityName = sInfo['city'];
              lat = sInfo['lat'];
              lng = sInfo['lng'];
            }

            final isDerby = _isDerbyMatch(homeName, awayName);
            final isPopular = isDerby ||
                homeName.contains('Madrid') ||
                homeName.contains('Barça') ||
                homeName.contains('Barcelona') ||
                homeName.contains('Manchester') ||
                homeName.contains('Arsenal') ||
                homeName.contains('Liverpool') ||
                homeName.contains('Bayern') ||
                homeName.contains('Paris') ||
                homeName.contains('Milan') ||
                homeName.contains('Inter') ||
                homeName.contains('Juventus');

            events.add(EventModel(
              id: 'footballdata_$mId',
              title: matchTitle,
              category: '⚽ Spor Müsabakaları',
              location: '$venueName, $cityName',
              dateTime: matchDate,
              description: '$compName karşılaşması! $homeName ve $awayName yeşil sahada kozlarını paylaşıyor. Maçı canlı takip edecek veya stadyumda birlikte izleyecek taraftarlarla bir araya gelin.',
              imageUrl: _getFootballImage(homeName, awayName),
              latitude: lat ?? 41.0082,
              longitude: lng ?? 28.9784,
              ticketUrl: null, // KURAL: Spor müsabakalarında bilet linki kesinlikle olmaz
              ticketProvider: null,
              atmosphere: isDerby ? '🔥 Büyük Derbi' : '🏆 $compName',
              isPopular: isPopular,
            ));
          } catch (e) {
            debugPrint('[SportsApiService] Maç ayrıştırma hatası: $e');
          }
        }
      } else if (res.statusCode == 429) {
        final waitSec = res.headers['x-requestcounter-reset'] ?? '60';
        debugPrint('[SportsApiService] ⚠️ Football-Data.org Hız Sınırı (429): Lütfen $waitSec saniye bekleyin.');
      } else {
        debugPrint('[SportsApiService] Football-Data.org yanıt kodu: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[SportsApiService] Football-Data.org sorgu hatası: $e');
    }

    return events;
  }

  /// ⚽ Canlı Süper Lig fikstürlerini ESPN Live Sports API üzerinden çeker (100% ücretsiz, canlı, gerçek tarihler ve saatler)
  Future<List<EventModel>> fetchLiveEspnSuperLigFixtures() async {
    final List<EventModel> events = [];
    final now = DateTime.now();

    try {
      final initialRes = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/soccer/tur.1/scoreboard'),
        headers: {'User-Agent': 'curl/8.4.0'},
      ).timeout(const Duration(seconds: 5));

      if (initialRes.statusCode != 200) {
        return events;
      }

      final initialData = jsonDecode(initialRes.body);
      final rawCal = (initialData['leagues'] as List?)?.firstOrNull?['calendar'] as List? ?? [];

      final upcomingDates = <String>[];
      for (var c in rawCal) {
        final dt = DateTime.tryParse(c.toString());
        if (dt != null && dt.isAfter(now.subtract(const Duration(days: 1))) && dt.isBefore(now.add(const Duration(days: 45)))) {
          final ymd = '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
          if (!upcomingDates.contains(ymd)) {
            upcomingDates.add(ymd);
          }
        }
      }

      final datesToFetch = upcomingDates.take(12).toList();
      final dayFutures = datesToFetch.map((ymd) async {
        try {
          final dayRes = await http.get(
            Uri.parse('https://site.api.espn.com/apis/site/v2/sports/soccer/tur.1/scoreboard?dates=$ymd'),
            headers: {'User-Agent': 'curl/8.4.0'},
          ).timeout(const Duration(seconds: 4));
          if (dayRes.statusCode == 200) {
            final dData = jsonDecode(dayRes.body);
            return dData['events'] as List? ?? [];
          }
        } catch (_) {}
        return [];
      });

      final dayResults = await Future.wait(dayFutures);
      final allRawEvents = <dynamic>[];

      final initialEvents = initialData['events'] as List? ?? [];
      allRawEvents.addAll(initialEvents);
      for (var list in dayResults) {
        allRawEvents.addAll(list);
      }

      final Set<String> seenEventIds = {};

      for (final rawEv in allRawEvents) {
        final evId = rawEv['id']?.toString();
        if (evId == null || seenEventIds.contains(evId)) continue;
        seenEventIds.add(evId);

        final comp = (rawEv['competitions'] as List?)?.firstOrNull;
        if (comp == null) continue;

        final competitors = comp['competitors'] as List? ?? [];
        final homeComp = competitors.firstWhere(
          (c) => c['homeAway'] == 'home',
          orElse: () => competitors.isNotEmpty ? competitors.first : null,
        );
        final awayComp = competitors.firstWhere(
          (c) => c['homeAway'] == 'away',
          orElse: () => competitors.length > 1 ? competitors[1] : null,
        );

        final rawHome = homeComp?['team']?['displayName']?.toString() ?? 'Ev Sahibi';
        final rawAway = awayComp?['team']?['displayName']?.toString() ?? 'Deplasman';
        final homeName = formatTeamName(rawHome);
        final awayName = formatTeamName(rawAway);
        final matchTitle = '$homeName - $awayName';

        final dtStr = rawEv['date']?.toString();
        if (dtStr == null) continue;
        final matchDate = DateTime.tryParse(dtStr)?.toLocal();
        if (matchDate == null) continue;

        if (matchDate.isBefore(now.subtract(const Duration(hours: 3)))) continue;

        final venue = comp['venue'];
        String venueName = venue?['fullName']?.toString() ?? '';
        String cityName = venue?['address']?['city']?.toString() ?? 'İstanbul';

        final stadiumKey = _resolveStadiumKey(homeName);
        double? lat;
        double? lng;
        if (stadiumCoordinates.containsKey(stadiumKey)) {
          final sInfo = stadiumCoordinates[stadiumKey]!;
          venueName = sInfo['name'];
          cityName = sInfo['city'];
          lat = sInfo['lat'];
          lng = sInfo['lng'];
        }

        final isDerby = _isDerbyMatch(homeName, awayName);

        events.add(EventModel(
          id: 'sports_espn_$evId',
          title: matchTitle,
          category: '⚽ Spor Müsabakaları',
          location: '${venueName.isNotEmpty ? venueName : "Stadyum"}, $cityName',
          dateTime: matchDate,
          description: 'Trendyol Süper Lig karşılaşması! $homeName ve $awayName sahada. Maçı stadyumda izleyecek veya maç öncesi buluşacak taraftarlarla bir araya gelin.',
          imageUrl: _getFootballImage(homeName, awayName),
          latitude: lat ?? 41.0082,
          longitude: lng ?? 28.9784,
          ticketUrl: null, // KURAL: Spor müsabakalarında bilet linki kesinlikle olmaz
          ticketProvider: null,
          atmosphere: isDerby ? '🔥 Büyük Derbi' : '⚽ Süper Lig',
          isPopular: isDerby || homeName.contains('Galatasaray') || homeName.contains('Fenerbahçe') || homeName.contains('Beşiktaş') || homeName.contains('Trabzonspor'),
        ));
      }
    } catch (e) {
      debugPrint('[SportsApiService] ESPN Süper Lig sorgu hatası: $e');
    }

    return events;
  }

  /// Yalnızca Futbol Müsabakalarını Çeker (Basketbol, Voleybol, Tenis kaldırılmıştır)
  Future<List<EventModel>> fetchAllSportsEvents() async {
    final List<EventModel> events = [];

    // 1. Önbellekte geçerli veri var mı kontrol et
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      return cached;
    }

    // 2. Canlı ESPN Süper Lig API'sinden maçları çek (Anahtarsız, 100% canlı Türkiye Süper Lig maçları)
    final espnMatches = await fetchLiveEspnSuperLigFixtures();
    if (espnMatches.isNotEmpty) {
      events.addAll(espnMatches);
      debugPrint('[SportsApiService] ⚽ ESPN Canlı Süper Lig: ${espnMatches.length} müsabaka çekildi.');
    }

    // 3. Football-Data.org API'sinden canlı Avrupa & Şampiyonlar Ligi maçlarını çek
    final footballDataMatches = await fetchLiveFootballDataOrgMatches();
    if (footballDataMatches.isNotEmpty) {
      for (var item in footballDataMatches) {
        if (!events.any((e) => e.title.toLowerCase() == item.title.toLowerCase())) {
          events.add(item);
        }
      }
      debugPrint('[SportsApiService] ⚽ Football-Data.org: ${footballDataMatches.length} müsabaka eklendi.');
    }

    // 4. Eğer internet bağlantısı yoksa veya liste boş kaldıysa küratörlü güncel futbol fikstür havuzunu ekle
    if (events.isEmpty) {
      final curatedList = _generateCuratedFootballFixtures();
      events.addAll(curatedList);
    }

    // 5. KESİN KURAL: Basketbol, Voleybol, Tenis kesinlikle bulunmamalıdır; sadece futbol maçları listelenir
    final strictlyFootballEvents = events.where((e) {
      final cat = e.category.toLowerCase();
      final title = e.title.toLowerCase();
      final desc = e.description.toLowerCase();
      final isNonFootball = cat.contains('basket') ||
          cat.contains('voleybol') ||
          cat.contains('tenis') ||
          title.contains('basket') ||
          title.contains('voleybol') ||
          title.contains('tenis') ||
          desc.contains('basket') ||
          desc.contains('voleybol') ||
          desc.contains('tenis') ||
          e.id.contains('_bb_') ||
          e.id.contains('_vb_') ||
          e.id.contains('_tn_');
      return !isNonFootball;
    }).toList();

    // 6. Tarihe göre sırala
    strictlyFootballEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 7. Önbelleğe kaydet
    await _saveToCache(strictlyFootballEvents);

    return strictlyFootballEvents;
  }

  static String _getFootballImage(String home, String away) {
    final h = home.toLowerCase();
    final a = away.toLowerCase();
    if (h.contains('galatasaray') || a.contains('galatasaray')) {
      return 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop';
    }
    if (h.contains('fenerbahçe') || a.contains('fenerbahçe') || h.contains('fenerbahce') || a.contains('fenerbahce')) {
      return 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80&w=1200&auto=format&fit=crop';
    }
    if (h.contains('beşiktaş') || a.contains('beşiktaş') || h.contains('besiktas') || a.contains('besiktas')) {
      return 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?q=80&w=1200&auto=format&fit=crop';
    }
    if (h.contains('madrid') || a.contains('madrid')) {
      return 'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?q=80&w=1200&auto=format&fit=crop';
    }
    if (h.contains('barcelona') || a.contains('barcelona') || h.contains('barça') || a.contains('barça')) {
      return 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80&w=1200&auto=format&fit=crop';
    }
    if (h.contains('liverpool') || a.contains('liverpool') || h.contains('arsenal') || a.contains('arsenal') || h.contains('manchester') || a.contains('manchester')) {
      return 'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9?q=80&w=1200&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop';
  }

  /// Çevrimdışı veya yedek durumlar için zengin, gerçekçi Futbol Derbileri ve Fikstür Havuzu
  /// (SADECE FUTBOL: Basketbol, Voleybol, Tenis KESİNLİKLE YOKTUR)
  List<EventModel> _generateCuratedFootballFixtures() {
    return [
      EventModel(
        id: 'spor_fb_gs_derbi_curated',
        title: 'Fenerbahçe - Galatasaray',
        category: '⚽ Spor Müsabakaları',
        location: 'Ülker Stadyumu Şükrü Saracoğlu, İstanbul',
        dateTime: makeUpcomingMatchDate(DateTime.sunday, 20, 0),
        description: 'Kıtalararası Dev Derbi! Kadıköy Ülker Stadyumu\'nda nefesler tutuluyor. Sarı-lacivertliler ile sarı-kırmızılılar tarihi rekabette kozlarını paylaşıyor.',
        imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80&w=1200&auto=format&fit=crop',
        latitude: 40.9877,
        longitude: 29.0369,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🔥 Kıtalararası Derbi',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_bjk_gs_derbi_curated',
        title: 'Beşiktaş - Galatasaray',
        category: '⚽ Spor Müsabakaları',
        location: 'Tüpraş Stadyumu, İstanbul',
        dateTime: makeUpcomingMatchDate(DateTime.saturday, 19, 0),
        description: 'Boğaz Kıyısında Büyük İstanbul Derbisi! Dolmabahçe Tüpraş Stadyumu\'nda muhteşem taraftar atmosferiyle Süper Lig randevusu.',
        imageUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?q=80&w=1200&auto=format&fit=crop',
        latitude: 41.0391,
        longitude: 28.9944,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🔥 Boğaz Derbisi',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_gs_ts_derbi_curated',
        title: 'Galatasaray - Trabzonspor',
        category: '⚽ Spor Müsabakaları',
        location: 'RAMS Park, İstanbul',
        dateTime: makeUpcomingMatchDate(DateTime.sunday, 19, 0),
        description: 'Trendyol Süper Lig Zirve Kapışması! RAMS Park Ali Sami Yen Spor Kompleksi tribünlerinde 50 bin taraftar tek yürek.',
        imageUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop',
        latitude: 41.1034,
        longitude: 28.9912,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🔥 Zirve Karşılaşması',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_ts_fb_derbi_curated',
        title: 'Trabzonspor - Fenerbahçe',
        category: '⚽ Spor Müsabakaları',
        location: 'Papara Park, Trabzon',
        dateTime: makeUpcomingMatchDate(DateTime.sunday, 19, 0),
        description: 'Karadeniz\'de Dev Randevu! Trabzon Papara Park fırtınalı bir atmosfere sahne oluyor. Süper Lig\'in en köklü rekabetlerinden biri.',
        imageUrl: 'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9?q=80&w=1200&auto=format&fit=crop',
        latitude: 40.9781,
        longitude: 39.6389,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🔥 Karadeniz Fırtınası',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_elclasico_curated',
        title: 'Real Madrid - FC Barcelona',
        category: '⚽ Spor Müsabakaları',
        location: 'Santiago Bernabéu, Madrid',
        dateTime: makeUpcomingMatchDate(DateTime.saturday, 22, 0),
        description: 'Dünya Futbolunun Zirvesi: El Clásico! Santiago Bernabéu stadyumunda iki İspanyol devi prestij ve liderlik için sahada.',
        imageUrl: 'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?q=80&w=1200&auto=format&fit=crop',
        latitude: 40.4530,
        longitude: -3.6883,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🏆 El Clásico',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_arsenal_mancity_curated',
        title: 'Arsenal - Manchester City',
        category: '⚽ Spor Müsabakaları',
        location: 'Emirates Stadium, Londra',
        dateTime: makeUpcomingMatchDate(DateTime.sunday, 18, 30),
        description: 'İngiltere Premier League Şampiyonluk Düellosu! Londra Emirates Stadyumu\'nda taktiksel satranç ve nefes kesen 90 dakika.',
        imageUrl: 'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9?q=80&w=1200&auto=format&fit=crop',
        latitude: 51.5549,
        longitude: -0.1084,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🏆 Premier League Dev Randevu',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_inter_milan_curated',
        title: 'Inter Milano - AC Milan',
        category: '⚽ Spor Müsabakaları',
        location: 'San Siro (Giuseppe Meazza), Milano',
        dateTime: makeUpcomingMatchDate(DateTime.sunday, 21, 45),
        description: 'Derby della Madonnina! İtalya Serie A\'nın efsanevi Milano derbisinde San Siro tribünlerinde koreografi şöleni.',
        imageUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80&w=1200&auto=format&fit=crop',
        latitude: 45.4781,
        longitude: 9.1240,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🔥 Milano Derbisi',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_bayern_dortmund_curated',
        title: 'Bayern München - Borussia Dortmund',
        category: '⚽ Spor Müsabakaları',
        location: 'Allianz Arena, Münih',
        dateTime: makeUpcomingMatchDate(DateTime.saturday, 19, 30),
        description: 'Almanya Der Klassiker! Allianz Arena\'da Bundesliga\'nın iki devi şampiyonluk yolunda karşı karşıya.',
        imageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?q=80&w=1200&auto=format&fit=crop',
        latitude: 48.2188,
        longitude: 11.6247,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🏆 Der Klassiker',
        isPopular: true,
      ),
      EventModel(
        id: 'spor_psg_marseille_curated',
        title: 'Paris Saint-Germain - Olympique de Marseille',
        category: '⚽ Spor Müsabakaları',
        location: 'Parc des Princes, Paris',
        dateTime: makeUpcomingMatchDate(DateTime.sunday, 21, 45),
        description: 'Fransa Le Classique! Parc des Princes tribünlerinde ateşli rekabet ve 3 puan savaşı.',
        imageUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?q=80&w=1200&auto=format&fit=crop',
        latitude: 48.8414,
        longitude: 2.2530,
        ticketUrl: null,
        ticketProvider: null,
        atmosphere: '🔥 Le Classique',
        isPopular: true,
      ),
    ];
  }

  Future<void> _saveToCache(List<EventModel> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = events.map((e) => e.toMap()).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<List<EventModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 3 saatten eski önbelleği tazele
      if (nowMs - cacheTime > const Duration(hours: 3).inMilliseconds) {
        return [];
      }

      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        final list = decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => EventModel.fromMap(m))
            .where((e) {
              // Önbellekte de non-football varsa kesinlikle süz
              final cat = e.category.toLowerCase();
              final title = e.title.toLowerCase();
              return !cat.contains('basket') &&
                  !cat.contains('voleybol') &&
                  !cat.contains('tenis') &&
                  !title.contains('basket') &&
                  !title.contains('voleybol') &&
                  !title.contains('tenis') &&
                  !e.id.contains('_bb_') &&
                  !e.id.contains('_vb_') &&
                  !e.id.contains('_tn_');
            })
            .toList();

        final now = DateTime.now();
        if (list.any((e) => e.dateTime.isBefore(now.subtract(const Duration(hours: 3))))) {
          return [];
        }

        return list;
      }
    } catch (_) {}
    return [];
  }
}
