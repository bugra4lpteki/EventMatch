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

    // 1. Konser / Sanatçı Etkinlikleri İçin Gerçek Spotify & Deezer Sanatçı Kapak (Artist Header) Görselleri
    if (titleLower.contains('sıla') || titleLower.contains('sila')) {
      // Sıla - Spotify Resmi Sanatçı Header/Profil Kapak Fotoğrafı (Siyah-Beyaz Çatı/Teras Oturan Sanatçı)
      return 'https://image-cdn-fa.spotifycdn.com/image/ab6761610000e5ebc6b5e030f9a843e7338bc5f1';
    }
    if (titleLower.contains('saint levant')) {
      // Saint Levant - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/ece5cdbf56a3cb10203a25d304543123/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('gogol bordello')) {
      // Gogol Bordello - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/8d846b93600b73317528218549796bed/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('black veil brides')) {
      // Black Veil Brides - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/8fbb449fa0c2e3512541a14479fc9086/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('snarky puppy')) {
      // Snarky Puppy - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/7e2d615395e8d77226a834a1dbc17c97/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('black label society')) {
      // Black Label Society - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/aefd3b0a13ddfcb4c7a83ec972704cc7/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('yann tiersen')) {
      // Yann Tiersen - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/5ea2f09e6a9c2c8dfc9800d0e4dc9e7c/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('p1harmony') || titleLower.contains('k-pop')) {
      // P1Harmony - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/70b34fc94718688cc4fc2ad107cda2c4/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('atb')) {
      // ATB - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/b1e0a8cbe4fab6a1d6cce98f761f05a5/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('arturo sandoval')) {
      // Arturo Sandoval - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/e407447716f4d7b8425c7f6dbd97ef5f/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('bilal')) {
      // Bilal - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/790bad91077a58d2b5bee2962b869f24/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('swallow the sun')) {
      // Swallow The Sun - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/e2c7fdc00ff93b9001964cfcf9136e93/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('infinity song')) {
      // Infinity Song - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/9867a472edb3fc382a8851442a4758a2/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('psly fest') || titleLower.contains('madrigal')) {
      // Madrigal - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/8705441c2e05aef465c76186af096845/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('mavi')) {
      // Mavi - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/110bfb39e7b5c3c54195da666efbd707/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('the sisters of mercy') || titleLower.contains('sisters of mercy')) {
      // The Sisters of Mercy - Resmi HD Sanatçı / Grup Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/d9ac1fd697d5ac6124413fa0441db6f1/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('the black keys') || titleLower.contains('black keys')) {
      // The Black Keys - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/3b27055c39125c3e3133a595990e86a1/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('buray')) {
      // Buray - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/7601b814af177071f16380fe73103faa/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('duman')) {
      // Duman - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/420bd789cacec4d562f981f6eae6c76e/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('levent yüksel') || titleLower.contains('levent yuksel')) {
      // Levent Yüksel - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/0af8ab7eb496aeb157a23b771211f859/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('gülşen') || titleLower.contains('gulsen')) {
      // Gülşen - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/b9794826785692d4d53b3a305733a0f0/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('blok3') || titleLower.contains('blok 3')) {
      // Blok3 - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/bcd7669bc107dd4b066deb45a31b1f9d/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('teoman')) {
      // Teoman - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/24cc2215cde1d249385ea6d466487a35/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('mor ve ötesi') || titleLower.contains('mor ve otesi')) {
      // Mor ve Ötesi - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/aee2502f3565318f12a5b90e9fb3d67c/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('manga')) {
      // maNga - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/3438c965f84d51d075f6418b4d5e81b8/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('athena')) {
      // Athena - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/e03f47be49d673d8f4b41cf03b5cf6b2/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('sezen aksu')) {
      // Sezen Aksu - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/9c62f746db8e41bb49eb13a3c254f597/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('tarkan')) {
      // Tarkan - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/28634a4ad808e5b6bbb6714f06bd5fe8/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('melike şahin') || titleLower.contains('melike sahin')) {
      // Melike Şahin - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/f54fb6a9276c943722a6dcb8c36852f4/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('madrigal')) {
      // Madrigal - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/8705441c2e05aef465c76186af096845/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('mabel matiz')) {
      // Mabel Matiz - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/200a518f2a5b6e5c3f215111275bac10/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('yüzyüzeyken') || titleLower.contains('yuzyuzeyken')) {
      // Yüzyüzeyken Konuşuruz - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/5aae600b68638b1c1b045ea15c7a7bcf/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('dolu kadehi ters tut')) {
      // Dolu Kadehi Ters Tut - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/a7893d2d70448584eca21168df34ceff/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('adamlar')) {
      // Adamlar - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/80cc98a7616cdede86fb44304a106bde/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('zeynep bastık') || titleLower.contains('zeynep bastik')) {
      // Zeynep Bastık - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/641b9164594081e14059fdf87404eb8d/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('kenan doğulu') || titleLower.contains('kenan dogulu')) {
      // Kenan Doğulu - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/c6676b89507b2f30a5ac8d67013beb7e/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('yalın') || titleLower.contains('yalin')) {
      // Yalın - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/83bea0c9b1f9e38efd2c38f60b99b079/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('edis')) {
      // Edis - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/f506aa24a14dabc72c980f2c41bdce24/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('simge')) {
      // Simge - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/908d0545255bdaa93da39e59631fa9aa/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('sefo')) {
      // Sefo - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/b0154dcf6895bb174cc2ba061f20481c/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('lvbel c5')) {
      // Lvbel C5 - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/55eba79b292dbef8e65d5b7b6873b9e8/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('uzi')) {
      // Uzi - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/65905c1901748c17c176bfd1889cc3ae/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('motive')) {
      // Motive - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/ed94718f8e0248951ed2c5c4ce54bf07/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('mert demir')) {
      // Mert Demir - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/52632ca5008fc35f5e13b32151b35c63/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('emir can iğrek') || titleLower.contains('emir can igrek')) {
      // Emir Can İğrek - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/c3fc5ee1e30c0c74a53ac0db86961cba/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('hande yener')) {
      // Hande Yener - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/541a70309fddeb75ba6c84d47ddff14d/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('sertab erener')) {
      // Sertab Erener - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/27bd9f43e71221d9ec1ad16cd0e0aa18/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('ebru gündeş') || titleLower.contains('ebru gundes')) {
      // Ebru Gündeş - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/f8b25e2db6bb1da6a82a41574e6c632e/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('candan erçetin') || titleLower.contains('candan ercetin')) {
      // Candan Erçetin - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/f848dbb2e179a34516e9faa8be82040b/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('haluk levent')) {
      // Haluk Levent - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/b0099ad3b700f88525fae5a3770f13fb/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('hayko cepkin')) {
      // Hayko Cepkin - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/450246fa5c528a31553bc5da2f0e4e0c/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('sagopa kajmer')) {
      // Sagopa Kajmer - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/b532395d78190bc78ef3a257bedd4e04/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('ceza')) {
      // Ceza - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/2af230afdd9e93989d7d7288e93fb536/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('dedublüman') || titleLower.contains('dedubluman')) {
      // Dedublüman - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/770829c037424b371faca8e33ef5e084/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('pinhani')) {
      // Pinhani - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/136e39be64687750265becbcb6084897/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('kalben')) {
      // Kalben - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/1ff0c67ed7724ec9a56048e86373b9ea/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('cem adrian')) {
      // Cem Adrian - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/eb3231ea3ca901fbd90cf6e4f17a18f3/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('fatma turgut')) {
      // Fatma Turgut - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/6cd73b1a945efdc107480ca72fd30bc9/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('gripin')) {
      // Gripin - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/4b35c0d255ee1b30a9a958a6317cd686/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('gökhan türkmen') || titleLower.contains('gokhan turkmen')) {
      // Gökhan Türkmen - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/637222df104c0fa3b1bf4ae6f9797aea/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('canozan')) {
      // Canozan - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/2ebf51cec9e59bc18f680e981696a41d/1000x1000-000000-80-0-0.jpg';
    }
    if (titleLower.contains('coldplay')) {
      // Coldplay - Resmi HD Sanatçı Görseli
      return 'https://cdn-images.dzcdn.net/images/artist/3087954bca22f306324912e5ac8375c3/1000x1000-000000-80-0-0.jpg';
    }

    // 2. Stand-up ve Komedi İçin Gerçek Görsel
    if (titleLower.contains('baturay') || titleLower.contains('özdemir')) {
      return 'https://images.bursadabugun.com/editor/haber/18022023/baturay-ozdemir-stand-up-gosterisi-ile-bursada-63f08fe717e13.jpg';
    }

    // Gelen url zaten geçerli bir CDN sanatçı görseli ise doğrudan koru
    if (url.contains('cdn-images.dzcdn.net') || (url.contains('spotifycdn.com') && !url.contains('ab67618600001016'))) {
      return url;
    }

    if (url.contains('a0f0fa47') || titleLower.contains('mavi')) {
      return 'https://cdn-images.dzcdn.net/images/artist/110bfb39e7b5c3c54195da666efbd707/1000x1000-000000-80-0-0.jpg';
    }

    // Generic, boş veya bozuk stok fotoğrafları kategorisine göre eşle (Asla yeşil-mavi konser stok görseline düşmez)
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
      return 'https://cdn-images.dzcdn.net/images/artist/24cc2215cde1d249385ea6d466487a35/1000x1000-000000-80-0-0.jpg';
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
