import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_match/core/services/content_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ContentFilterService.instance.setFilterEnabled(true);
  });

  group('ContentFilterService - Akıllı Sansür ve Kelime Koruması', () {
    test('İçinde sik, mal, got, am, pic kökleri geçen masum Türkçe kelimeler ASLA sansürlenmez', () {
      final filter = ContentFilterService.instance;

      expect(filter.censorText('klasik'), equals('klasik'));
      expect(filter.censorText('müzik'), equals('müzik'));
      expect(filter.censorText('eksik'), equals('eksik'));
      expect(filter.censorText('malzeme'), equals('malzeme'));
      expect(filter.censorText('maliyet'), equals('maliyet'));
      expect(filter.censorText('normal'), equals('normal'));
      expect(filter.censorText('termal'), equals('termal'));
      expect(filter.censorText('götürdü'), equals('götürdü'));
      expect(filter.censorText('göstermek'), equals('göstermek'));
      expect(filter.censorText('fiziksel'), equals('fiziksel'));
      expect(filter.censorText('taktik'), equals('taktik'));
      expect(filter.censorText('lastik'), equals('lastik'));
      expect(filter.censorText('fıstık'), equals('fıstık'));
      expect(filter.censorText('Malatya'), equals('Malatya'));
      expect(filter.censorText('ihtimal'), equals('ihtimal'));
    });

    test('Sıkıntı, sıkıldım gibi günlük masum sık- köklü kelimeler korunur', () {
      final filter = ContentFilterService.instance;

      expect(filter.censorText('Bugün hiçbir sıkıntı yok'), equals('Bugün hiçbir sıkıntı yok'));
      expect(filter.censorText('Evde çok sıkıldım'), equals('Evde çok sıkıldım'));
      expect(filter.censorText('Bu film aşırı sıkıcı'), equals('Bu film aşırı sıkıcı'));
      expect(filter.censorText('sıkı dostlar'), equals('sıkı dostlar'));
      expect(filter.censorText('sıkça görüşürüz'), equals('sıkça görüşürüz'));
    });

    test('Cümle içerisindeki masum kelimeler korunurken gerçek küfürler sansürlenir', () {
      final filter = ContentFilterService.instance;

      final input = 'Klasik müzik dinlerken malzeme eksik diye siktir git dedi.';
      final output = filter.censorText(input);

      // 'Klasik', 'müzik', 'malzeme', 'eksik' korunmalı; 'siktir' sansürlenmeli
      expect(output.contains('Klasik'), isTrue);
      expect(output.contains('müzik'), isTrue);
      expect(output.contains('malzeme'), isTrue);
      expect(output.contains('eksik'), isTrue);
      expect(output.contains('siktir'), isFalse);
      expect(output.contains('******'), isTrue);
    });

    test('Açık argo ve küfürler başarıyla maskelenir', () {
      final filter = ContentFilterService.instance;

      expect(filter.censorText('orospu'), equals('******'));
      expect(filter.censorText('yavşak'), equals('******'));
      expect(filter.censorText('sen tam bir malsın'), equals('sen tam bir ******'));
      expect(filter.censorText('amk'), equals('***'));
      expect(filter.censorText('aq'), equals('**'));
      expect(filter.censorText('orospu çocuğu'), equals('*************'));
      expect(filter.censorText('amına koyayım'), equals('*************'));
    });

    test('containsObjectionableContent fonksiyonu doğru tespit yapar', () {
      final filter = ContentFilterService.instance;

      expect(filter.containsObjectionableContent('Konser için klasik müzik dinliyorum.'), isFalse);
      expect(filter.containsObjectionableContent('Eksik malzeme kaldı, normal bir gün.'), isFalse);
      expect(filter.containsObjectionableContent('Beni arabayla eve götürdü.'), isFalse);
      expect(filter.containsObjectionableContent('Hiçbir sıkıntı yok canım.'), isFalse);

      expect(filter.containsObjectionableContent('siktir git'), isTrue);
      expect(filter.containsObjectionableContent('sen tam bir malsın'), isTrue);
      expect(filter.containsObjectionableContent('orospu'), isTrue);
    });
  });

  group('ContentFilterService - Kullanıcı Kontrolü (Açma/Kapatma)', () {
    test('Kullanıcı filtreyi kapattığında sansür tamamen devre dışı kalır', () async {
      final filter = ContentFilterService.instance;

      await filter.setFilterEnabled(false);
      expect(filter.isFilterEnabled, isFalse);

      const rawMessage = 'siktir git buradan orospu çocuğu';
      final filteredMessage = filter.censorText(rawMessage);

      // Filtre kapalıyken metin tamamen olduğu gibi kalmalı
      expect(filteredMessage, equals(rawMessage));
    });

    test('Kullanıcı filtreyi tekrar açtığında sansür yeniden çalışır', () async {
      final filter = ContentFilterService.instance;

      await filter.setFilterEnabled(false);
      expect(filter.censorText('siktir git'), equals('siktir git'));

      await filter.setFilterEnabled(true);
      expect(filter.isFilterEnabled, isTrue);
      expect(filter.censorText('siktir git'), equals('****** git'));
    });
  });
}
