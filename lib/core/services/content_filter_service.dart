/// ContentFilterService
/// Apple App Store Guideline 1.2 (Safety - User Generated Content) uyumluluğu için
/// otomatik sakıncalı / uygunsuz içerik filtreleme servisi.
class ContentFilterService {
  ContentFilterService._();
  static final ContentFilterService instance = ContentFilterService._();

  // Yaygın sakıncalı / küfür / hakaret / nefret söylemi kökleri (TR & EN)
  static final List<String> _objectionableKeywords = [
    // Genel Türkçe küfür & hakaret kökleri
    'orospu', 'piç', 'yavşak', 'sik', 'sikerim', 'yarrak', 'amcık', 'göt', 'ibne',
    'kahpe', 'puşt', 'pezevenk', 'gavat', 'mal', 'salak', 'aptal', 'gerizekalı',
    'sürtük', 'fahise', 'fahişe', 'şerefsiz', 'haysiyetsiz', 'namussuz',
    'terörist', 'katil', 'tecavüz', 'pedofili', 'ensest',
    // İngilizce yaygın terimler
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'bastard', 'cunt',
    'whore', 'slut', 'nigger', 'faggot', 'kill yourself', 'die', 'retard',
    'nazi', 'terrorist', 'porn', 'sex', 'blowjob', 'rape'
  ];

  /// Verilen metinde sakıncalı içerik var mı kontrol eder
  bool containsObjectionableContent(String text) {
    if (text.trim().isEmpty) return false;
    final normalized = _normalizeText(text);

    for (final word in _objectionableKeywords) {
      // Kelime veya kelime öbeği eşleşmesi
      if (normalized.contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Sakıncalı kelimeleri *** ile maskeler
  String censorText(String text) {
    if (text.trim().isEmpty) return text;
    String result = text;

    for (final word in _objectionableKeywords) {
      final regExp = RegExp(RegExp.escape(word), caseSensitive: false);
      result = result.replaceAllMapped(regExp, (match) {
        final len = match.group(0)!.length;
        return '*' * len;
      });
    }
    return result;
  }

  /// Metni Türkçe karakterler ve özel karakterler için normalize eder
  String _normalizeText(String input) {
    var output = input.toLowerCase();
    output = output
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    // Sayısal hileleri ve leetspeak karakterlerini temizle (ör: s1k, 0rospu)
    output = output
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll(RegExp(r'[^a-z\s]'), '');
    return output;
  }
}
