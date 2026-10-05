import 'package:flutter_test/flutter_test.dart';
import 'package:event_match/features/events/services/spotify_service.dart';

void main() {
  group('Spotify Festival ve Sanatçı Filtreleme Testleri', () {
    test('1. "Sakarya Festivali - Kombine" etkinliği şehir adını ASLA sanatçı olarak döndürmemelidir', () {
      final artists = SpotifyService.extractArtistNames('Sakarya Festivali - Kombine');
      expect(artists, isEmpty, reason: 'Şehir veya festival kombine bilet adı sanatçı olarak algılanmamalıdır');
    });

    test('2. 81 il ve festival/bilet tokenları isInvalidArtistToken tarafından filtrelenmelidir', () {
      expect(SpotifyService.isInvalidArtistToken('Sakarya'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('sakarya'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('İstanbul'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('Ankara'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('İzmir'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('Kombine'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('Festivali'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('Sakarya Festivali'), isTrue);
      expect(SpotifyService.isInvalidArtistToken('Kombine Bilet'), isTrue);

      // Gerçek sanatçılar engellenmemelidir
      expect(SpotifyService.isInvalidArtistToken('Teoman'), isFalse);
      expect(SpotifyService.isInvalidArtistToken('Duman'), isFalse);
      expect(SpotifyService.isInvalidArtistToken('Mor ve Ötesi'), isFalse);
      expect(SpotifyService.isInvalidArtistToken('Sıla'), isFalse);
    });

    test('3. Sanatçılı konser ve festivallerde gerçek sanatçılar doğru ayıklanmalıdır', () {
      final singleArtist = SpotifyService.extractArtistNames('Motive Konseri');
      expect(singleArtist, contains('Motive'));

      final duo = SpotifyService.extractArtistNames('Sibel Can & Eypio Harbiye Açıkhava Konserleri');
      expect(duo, containsAll(['Sibel Can', 'Eypio']));

      final band = SpotifyService.extractArtistNames('Mor ve Ötesi - Canlı Sahne');
      expect(band, contains('Mor ve Ötesi'));
    });

    test('4. Festival açıklamasında yer alan sanatçılar başarıyla tespit edilmelidir', () {
      final festivalWithLineup = SpotifyService.extractArtistNames(
        'Sakarya Festivali - Kombine',
        description: 'Bu yıl Sakarya sahnesinde Teoman, Manga ve Sıla rüzgarı esecek!',
      );
      expect(festivalWithLineup, containsAll(['Teoman', 'Manga', 'Sıla']));
      expect(festivalWithLineup.contains('Sakarya'), isFalse, reason: 'Sakarya şehri listede yer almamalıdır');
    });

    test('5. Trakya, Karadeniz veya diğer bölgesel festival biletleri de boş sanatçı döndürmelidir', () {
      expect(SpotifyService.extractArtistNames('Trakya Müzik Festivali - 3. Gün'), isEmpty);
      expect(SpotifyService.extractArtistNames('Ege Gençlik Festivali Kombine'), isEmpty);
    });
  });
}
