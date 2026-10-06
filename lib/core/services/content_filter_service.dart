import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ContentFilterService
/// Apple App Store Guideline 1.2 (Safety - User Generated Content) uyumluluğu için
/// akıllı ve kullanıcı kontrollü uygunsuz içerik filtreleme servisi.
///
/// Klasik "Scunthorpe" sorununu çözmek amacıyla normal kelimelerin
/// (örneğin: "klasik", "malzeme", "normal", "eksik", "müzik", "götürdü", "fiziksel")
/// içindeki heceleri ASLA bozmaz. Sadece gerçek argo/küfür kelimelerini hedefler.
/// Kullanıcı Ayarlar -> Hesap Gizliliği ekranından bu filtreyi açıp kapatabilir.
class ContentFilterService extends ChangeNotifier {
  ContentFilterService._() {
    _loadPreference();
  }
  static final ContentFilterService instance = ContentFilterService._();

  static const String _prefKey = 'content_filter_enabled';
  bool _isFilterEnabled = true;

  /// Filtrenin o an aktif olup olmadığını döndürür
  bool get isFilterEnabled => _isFilterEnabled;

  /// SharedPreferences'tan kullanıcının tercihini yükler
  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isFilterEnabled = prefs.getBool(_prefKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  /// Kullanıcının sansür tercihini günceller ve kaydeder
  Future<void> setFilterEnabled(bool enabled) async {
    _isFilterEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  // --- KELİME BEYAZ LİSTESİ (Asla sansürlenmeyecek masum kelimeler ve kökler) ---
  static const Set<String> _whitelistWords = {
    // 'mal' içeren masum kelimeler
    'normal', 'normale', 'normali', 'normalde', 'normaldir', 'normaller', 'normallik',
    'termal', 'termali', 'termalde',
    'formal', 'formalite', 'formaliteler',
    'malzeme', 'malzemeler', 'malzemesi', 'malzemeleri', 'malzemelerimiz', 'malzemeli',
    'maliyet', 'maliyeti', 'maliyetler', 'maliyetli', 'maliyetsiz',
    'mali', 'maliye', 'maliyesi', 'malikane', 'malkoc', 'malkocoglu',
    'imal', 'imalat', 'imalathane', 'imalati',
    'kemal', 'cemal', 'damla', 'damlalar', 'klimali', 'klimalar',
    // 'sik' / 'sık' içeren masum kelimeler
    'klasik', 'klasikler', 'klasigi', 'klasiklesmis', 'klasiklesmisler',
    'eksik', 'eksigi', 'eksikler', 'eksiklik', 'eksiklikler', 'eksiksiz', 'eksiksizce',
    'fizik', 'fiziksel', 'fiziki', 'fizikci', 'fizikciler',
    'muzik', 'muzikal', 'muzisyen', 'muzikler', 'muziksever',
    'taktik', 'taktikler', 'taktiksel',
    'lastik', 'lastikler',
    'fistik', 'fistikli',
    'kisik', 'basik', 'kesik', 'asik', 'isik', 'delik', 'delikli', 'patik', 'besik', 'vesika',
    'sikinti', 'sikintilar', 'sikintili', 'sikintisiz', 'sikintim', 'sikintiniz',
    'sikildim', 'sikildik', 'sikildin', 'sikildi', 'sikilmis', 'sikilmak', 'sikilma', 'sikici', 'sikilinca', 'sikilgan',
    'siki', 'sikica', 'sikilik', 'sikiyonetim',
    'sikca', 'siklik', 'siklikla',
    'siklet', 'sikke', 'siklamen',
    'sikisik', 'sikisiklik', 'sikismak', 'sikistik', 'sikisma', 'sikistirma', 'sikistir',
    'siktik', 'siktim', 'sikti',
    // 'mal' içeren diğer masum kelimeler
    'malatya', 'malatyali', 'malezya', 'maldivler', 'malum', 'malul', 'malulen',
    'ihmal', 'ihmalkar', 'ihmaller', 'ihtimal', 'ihtimaller',
    'hamal', 'hamallik', 'hamallar', 'sarmal', 'kumsal',
    // 'got' içeren masum kelimeler
    'gotur', 'goturmek', 'goturdu', 'goturur', 'gotursun', 'goturdum', 'goturu', 'goturun', 'goturduler', 'goturecek', 'goturmus',
    'goster', 'gosteri', 'gostermek', 'gosterdi', 'gosterir', 'gosteris', 'gosterisi', 'gosteriler', 'gosterecek',
    'gozet', 'gozetmen', 'gozetlemek', 'gozetti',
    'goteborg',
    // Diğer benzer kelimeler
    'sigorta', 'biseksuel', 'aseksuel', 'heteroseksuel', 'diyet', 'diyetetik', 'diyetisyen', 'diesel', 'dizel',
    'tamam', 'aksam', 'hamam', 'adam', 'makam', 'imam', 'cam', 'dam', 'roman',
    'amca', 'amber', 'amblem', 'ampul', 'ambalaj', 'amerika', 'amator', 'ameliyat', 'amiral', 'amin', 'amma', 'ama',
    'pilav', 'pilic', 'cekic', 'kirec', 'sec', 'ic', 'hic', 'pis', 'bicak'
  };

  // --- KÜFÜR VE ARGO KONTROL LİSTELERİ ---
  static const Set<String> _standaloneMal = {
    'mal', 'malsin', 'mallar', 'mala', 'malin', 'malken', 'malca', 'mallik', 'maloglu'
  };

  static const Set<String> _standaloneGot = {
    'got', 'gotu', 'gote', 'gotun', 'gotler', 'gotsun', 'gotlek', 'gotos', 'gotveren'
  };

  static const Set<String> _standalonePic = {
    'pic', 'pici', 'picler', 'piclik', 'picin', 'pico'
  };

  static const Set<String> _standaloneAm = {
    'amcik', 'amcigi', 'amina', 'amini', 'amk', 'aq', 'amq', 'aminakoyim', 'amkoyim', 'amguard'
  };

  // Belirgin ve şüphesiz küfür kökleri
  static const List<String> _distinctProfanityPrefixes = [
    'orospu',
    'yavsak',
    'kahpe',
    'pust',
    'pezevenk',
    'gavat',
    'kavat',
    'surtuk',
    'fahise',
    'serefsiz',
    'haysiyetsiz',
    'namussuz',
    'yarrak',
    'yarrag',
    'yarak',
    'yarag',
    'tecavuz',
    'pedofili',
    'ensest',
    'salak',
    'aptal',
    'gerizekali',
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'dick',
    'pussy',
    'bastard',
    'cunt',
    'whore',
    'slut',
    'nigg',
    'faggot',
    'retard',
    'blowjob',
  ];

  /// Verilen metinde sakıncalı içerik var mı kontrol eder
  bool containsObjectionableContent(String text) {
    if (text.trim().isEmpty) return false;

    // Çok kelimeli ifadeler
    if (_hasMultiWordProfanity(text)) return true;

    final tokenRegex = RegExp(r'[a-zA-ZçÇğĞıİöÖşŞüÜ0-9]+');
    for (final match in tokenRegex.allMatches(text)) {
      final token = match.group(0)!;
      if (_isProfaneToken(token)) {
        return true;
      }
    }
    return false;
  }

  /// Sakıncalı kelimeleri akıllıca *** ile maskeler.
  /// Kullanıcı ayarlarından filtre kapatıldıysa metni olduğu gibi döndürür.
  String censorText(String text) {
    if (!_isFilterEnabled || text.trim().isEmpty) return text;

    String result = text;

    // 1. Çok kelimeli kalıp küfürleri maskele
    result = _maskMultiWordProfanities(result);

    // 2. Kelime bazlı akıllı maskeleme
    final tokenRegex = RegExp(r'[a-zA-ZçÇğĞıİöÖşŞüÜ0-9]+');
    result = result.replaceAllMapped(tokenRegex, (match) {
      final token = match.group(0)!;
      if (_isProfaneToken(token)) {
        return '*' * token.length;
      }
      return token;
    });

    return result;
  }

  /// Çok kelimeli küfür öbeklerini sansürler
  String _maskMultiWordProfanities(String text) {
    String res = text;
    final patterns = [
      RegExp(r'orospu\s+çocu[gğ]u[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'orospu\s+cocu[gğ]u[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'am[ıi]na\s+koy[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'am[ıi]n[ıi]\s+sikeyim[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'kill\s+yourself', caseSensitive: false),
    ];

    for (final p in patterns) {
      res = res.replaceAllMapped(p, (m) {
        final val = m.group(0)!;
        return '*' * val.length;
      });
    }
    return res;
  }

  bool _hasMultiWordProfanity(String text) {
    final patterns = [
      RegExp(r'orospu\s+çocu[gğ]u[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'orospu\s+cocu[gğ]u[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'am[ıi]na\s+koy[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'am[ıi]n[ıi]\s+sikeyim[a-zA-ZçÇğĞıİöÖşŞüÜ]*', caseSensitive: false),
      RegExp(r'kill\s+yourself', caseSensitive: false),
    ];
    for (final p in patterns) {
      if (p.hasMatch(text)) return true;
    }
    return false;
  }

  /// Bir kelime token'ının gerçekten argo/küfür olup olmadığını denetler
  bool _isProfaneToken(String token) {
    if (token.length < 2) return false;

    final norm = _normalizeToken(token);

    // Beyaz listede ise ASLA küfür değildir (örn: "klasik", "malzeme", "normal", "eksik", "müzik")
    if (_whitelistWords.contains(norm)) {
      return false;
    }

    // Kısa ve spesifik küfür denetimleri
    if (_standaloneMal.contains(norm)) return true;
    if (_standaloneGot.contains(norm)) return true;
    if (_standalonePic.contains(norm)) return true;
    if (_standaloneAm.contains(norm)) return true;
    if (norm == 'die' || norm == 'sex' || norm == 'seks' || norm == 'ibne') return true;

    // 'sik' denetimi: SADECE belirgin küfürler ('klasik', 'eksik', 'müzik', 'sıkıntı', 'sıkıldım' ASLA kapsanmaz)
    if (norm == 'sik') return true;
    if (norm.startsWith('siktir') ||
        norm.startsWith('sikik') ||
        norm.startsWith('sikey') ||
        norm.startsWith('siker') ||
        norm.startsWith('sikecek') ||
        norm.startsWith('sikemez') ||
        norm.startsWith('siktigim') ||
        norm.startsWith('hassiktir') ||
        norm.startsWith('hasiktir')) {
      return true;
    }
    if (norm.startsWith('sikis') &&
        !norm.startsWith('sikisik') &&
        !norm.startsWith('sikism') &&
        !norm.startsWith('sikist')) {
      return true;
    }

    // Belirgin küfür kökleri kontrolü
    for (final prefix in _distinctProfanityPrefixes) {
      if (norm.startsWith(prefix)) {
        return true;
      }
    }

    return false;
  }

  /// Token'ı Türkçe harf duyarlılığı ve leetspeak hilelerine karşı normalize eder
  String _normalizeToken(String input) {
    var output = input.toLowerCase();
    output = output
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's');
    return output;
  }
}
