import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';

class MockEventService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  MockEventService() {
    loadUserProfile();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      final data = await _supabase.from('events').select();
      
      // Keep existing mock events for attendees, or clear and replace?
      // User says "artık etkinlikleri çekmek istiyorum", so we should replace the list.
      _events.clear();
      
      for (var item in data) {
        _events.add(EventModel.fromJson(item));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase Events Error: $e');
    }
  }

  Future<void> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    final authUser = _supabase.auth.currentUser;
    final userId = authUser?.id ?? 'user_1';
    currentUser.id = userId;

    // Reset to clean slate first (prevent carryover from previous accounts)
    currentUser.username = null;
    currentUser.city = null;
    currentUser.gender = null;
    currentUser.aboutMe = null;
    currentUser.birthDate = null;
    currentUser.tags = [];
    currentUser.socialLinks = [];
    currentUser.avatarUrl = '';
    currentUser.avatarUrls = [];
    currentUser.plannedEvents = [];
    currentUser.pastEvents = [];

    if (userId != 'user_1') {
      // Kullanıcı giriş yapmış, veritabanından çek (Supabase)
      try {
        final userData = await _supabase.from('users').select().eq('id', userId).maybeSingle();
        if (userData != null) {
          currentUser.username = userData['username'];
          currentUser.city = userData['city'];
          currentUser.gender = userData['gender'];
          currentUser.aboutMe = userData['bio'];
          if (userData['birth_date'] != null) {
            currentUser.birthDate = DateTime.tryParse(userData['birth_date']);
          }
          if (userData['interests'] != null) {
            currentUser.tags = List<String>.from(userData['interests'] as List);
          }
          
          // Öncelikli olarak veritabanındaki ismi al, yoksa metadata'dan al
          currentUser.name = userData['name'] ?? authUser?.userMetadata?['name'] ?? 'Yeni Kullanıcı';
        } else {
          // Tabloda yoksa metadata'dan sadece ismi al
          currentUser.name = authUser?.userMetadata?['name'] ?? 'Yeni Kullanıcı';
        }
        
        // user_photos tablosundan fotoğrafları çek
        try {
          final photos = await _supabase.from('user_photos').select().eq('user_id', userId).eq('is_active', true).order('sort_order');
          if (photos.isNotEmpty) {
            currentUser.avatarUrls = photos.map((p) => p['storage_url'].toString()).toList();
            currentUser.avatarUrl = currentUser.avatarUrls.first;
          }
        } catch (_) {}

        // user_social_links tablosundan linkleri çek
        try {
          final links = await _supabase.from('user_social_links').select().eq('user_id', userId);
          if (links.isNotEmpty) {
            currentUser.socialLinks = links.map((l) => l['url'].toString()).toList();
          }
        } catch (_) {}
        // event_attendees tablosundan katıldığı etkinlikleri çek
        try {
          final attendedRes = await _supabase.from('event_attendees')
              .select('event_id')
              .eq('user_id', userId)
              .eq('status', 'joined');
          
          if (attendedRes.isNotEmpty) {
            currentUser.plannedEvents = attendedRes.map((r) => r['event_id'].toString()).toList();
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('Supabase profile load error: $e');
      }
    } else {
      // Mock kullanıcı mantığı veya yedek SharedPreferences okuması
      currentUser.name = prefs.getString('${userId}_userName') ?? 'Ali Rıza';
      currentUser.username = prefs.getString('${userId}_userUsername') ?? 'aliriza';
      
      final birthDateStr = prefs.getString('${userId}_userBirthDate');
      currentUser.birthDate = birthDateStr != null ? DateTime.tryParse(birthDateStr) : DateTime(1998, 1, 1);

      currentUser.city = prefs.getString('${userId}_userCity') ?? 'İstanbul';
      currentUser.gender = prefs.getString('${userId}_userGender') ?? 'Erkek';
      currentUser.aboutMe = prefs.getString('${userId}_userAboutMe') ?? 'Yeni insanlarla tanışmayı ve yeni etkinlikler keşfetmeyi severim.';
      
      currentUser.socialLinks = prefs.getStringList('${userId}_userSocialLinks') ?? ['https://instagram.com/eventmatch', 'https://x.com/eventmatch'];
      currentUser.avatarUrl = prefs.getString('${userId}_userAvatarUrl') ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100';
      currentUser.avatarUrls = prefs.getStringList('${userId}_userAvatarUrls') ?? ['https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100'];
    }

    // Ortak veriler (Etkinlik planları lokal tutuluyor olabilir)
    if (userId == 'user_1') {
      final tags = prefs.getStringList('${userId}_userTags');
      if (tags != null) currentUser.tags = tags;

      final plannedEvents = prefs.getStringList('${userId}_plannedEvents');
      if (plannedEvents != null) {
        currentUser.plannedEvents = plannedEvents;
      }
    }
    
    final pastEvents = prefs.getStringList('${userId}_userPastEvents');
    if (pastEvents != null) currentUser.pastEvents = pastEvents;

    // Etkinliklere katılımcı olarak kendimizi ekleme (UI ve yerel verilerin senkronize olması için)
    for (var eventId in currentUser.plannedEvents) {
      final event = getEventById(eventId);
      if (event != null && !event.attendees.any((u) => u.id == currentUser.id)) {
        event.attendees.add(UserModel(
          id: currentUser.id,
          name: currentUser.name,
          avatarUrl: currentUser.avatarUrl,
          city: currentUser.city,
          birthDate: currentUser.birthDate,
          tags: List.from(currentUser.tags),
        ));
      }
    }
    notifyListeners();
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUser.id;
    await prefs.setString('${userId}_userName', currentUser.name);
    if (currentUser.username != null) {
      await prefs.setString('${userId}_userUsername', currentUser.username!);
    }
    if (currentUser.birthDate != null) {
      await prefs.setString('${userId}_userBirthDate', currentUser.birthDate!.toIso8601String());
    }
    await prefs.setString('${userId}_userCity', currentUser.city ?? '');
    await prefs.setString('${userId}_userGender', currentUser.gender ?? '');
    await prefs.setString('${userId}_userAboutMe', currentUser.aboutMe ?? '');
    await prefs.setStringList('${userId}_userSocialLinks', currentUser.socialLinks);
    await prefs.setString('${userId}_userAvatarUrl', currentUser.avatarUrl);
    await prefs.setStringList('${userId}_userAvatarUrls', currentUser.avatarUrls);
    await prefs.setStringList('${userId}_userTags', currentUser.tags);
    await prefs.setStringList('${userId}_plannedEvents', currentUser.plannedEvents);
    await prefs.setStringList('${userId}_userPastEvents', currentUser.pastEvents);
  }

  Future<void> _savePlannedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUser.id;
    await prefs.setStringList('${userId}_plannedEvents', currentUser.plannedEvents);
  }
  final UserModel currentUser = UserModel(
    id: 'user_1',
    name: 'Ali Rıza',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100',
    avatarUrls: ['https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100'],
    birthDate: DateTime(1998, 1, 1),
    city: 'İstanbul',
    aboutMe: 'Yeni insanlarla tanışmayı ve yeni etkinlikler keşfetmeyi severim.',
    socialLinks: ['https://instagram.com/eventmatch', 'https://x.com/eventmatch'],
    tags: ['Techno', 'Kahve', 'Gaming'],
    points: 1250,
    badges: ['Sahne Tozu Yutmuş', 'Müzik Tutkunu'],
    plannedEvents: ['e_kacpara_1', 'e_baturay_2'],
    pastEvents: ['e_agaclar_1'],
  );

  Future<void> updateCurrentUser({
    required String name,
    String? username,
    String? city,
    String? gender,
    required String aboutMe,
    List<String>? socialLinks,
    required String avatarUrl,
    List<dynamic>? avatarImages,
    List<String>? tags,
    List<String>? plannedEvents,
    List<String>? pastEvents,
  }) async {
    final userId = currentUser.id;
    List<String> finalAvatarUrls = [];

    if (avatarImages != null) {
      for (var item in avatarImages) {
        if (item is String) {
          finalAvatarUrls.add(item);
        } else if (item is XFile) {
          finalAvatarUrls.add(item.path);
        }
      }
    }

    if (userId != 'user_1') {
      try {
        // 1. users Tablosunu Güncelle (İsim alanı varsa orayı da güncelleriz, yoksa sadece diğer alanları güncelleriz)
        try {
          await _supabase.from('users').update({
            'name': name,
            'username': username,
            'city': city,
            'gender': gender,
            'bio': aboutMe,
            if (tags != null) 'interests': tags,
          }).eq('id', userId);
        } catch (e) {
          debugPrint('users tablosuna name yazılamadı, name kolonu olmayabilir. Hata: $e');
          // 'name' kolonunun olmadığını varsayarak name parametresiz tekrar deniyoruz
          await _supabase.from('users').update({
            'username': username,
            'city': city,
            'gender': gender,
            'bio': aboutMe,
            if (tags != null) 'interests': tags,
          }).eq('id', userId);
        }

        // Auth metadata'yı da güncelleyebiliriz (isim için)
        await _supabase.auth.updateUser(UserAttributes(
          data: {'name': name, 'username': username},
        ));

        // 2. Sosyal Linkleri Güncelle
        if (socialLinks != null) {
          await _supabase.from('user_social_links').delete().eq('user_id', userId);
          if (socialLinks.isNotEmpty) {
            final linksData = socialLinks.map((link) => {
              'user_id': userId,
              'url': link
            }).toList();
            await _supabase.from('user_social_links').insert(linksData);
          }
        }

        // 3. Fotoğrafları Güncelle
        if (avatarImages != null) {
          finalAvatarUrls.clear();
          int photoIndex = 0;
          for (var item in avatarImages) {
            if (item is String) {
              finalAvatarUrls.add(item);
            } else if (item is XFile) {
              try {
                final pathInBucket = '${userId}/foto_${DateTime.now().millisecondsSinceEpoch}_$photoIndex.jpg';
                final bytes = await item.readAsBytes();
                
                // 1. Önce Storage'a yükle
                await _supabase.storage.from('avatars').uploadBinary(
                  pathInBucket,
                  bytes,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: false,
                    contentType: 'image/jpeg',
                  ),
                );
                
                // 2. Public URL al
                final publicUrl = _supabase.storage.from('avatars').getPublicUrl(pathInBucket);
                finalAvatarUrls.add(publicUrl);
              } catch (e) {
                debugPrint('Foto yükleme hatası: $e');
                finalAvatarUrls.add(item.path);
              }
            }
            photoIndex++;
          }
          
          // 3. Sonra user_photos'a kaydet (Eski fotoğrafları silip sırayla ekliyoruz)
          await _supabase.from('user_photos').delete().eq('user_id', userId);
          if (finalAvatarUrls.isNotEmpty) {
            final photosData = finalAvatarUrls.asMap().entries.map((entry) => {
              'user_id': userId,
              'storage_url': entry.value,
              'sort_order': entry.key,
              'is_active': true
            }).toList();
            await _supabase.from('user_photos').insert(photosData);
          }
        }
      } catch (e) {
        debugPrint('Profil güncelleme hatası: $e');
        throw Exception('Profil güncellenirken bir hata oluştu: $e');
      }
    }

    currentUser.name = name;
    if (username != null) currentUser.username = username;
    if (city != null) currentUser.city = city;
    if (gender != null) currentUser.gender = gender;
    currentUser.aboutMe = aboutMe;
    if (socialLinks != null) currentUser.socialLinks = socialLinks;
    
    if (avatarImages != null) {
      currentUser.avatarUrls = finalAvatarUrls;
      if (finalAvatarUrls.isNotEmpty) {
        currentUser.avatarUrl = finalAvatarUrls.first;
      } else {
        currentUser.avatarUrl = '';
      }
    }
    if (tags != null) {
      currentUser.tags = tags;
    }
    if (plannedEvents != null) {
      currentUser.plannedEvents = plannedEvents;
    }
    if (pastEvents != null) {
      currentUser.pastEvents = pastEvents;
    }
    _saveProfileData();
    notifyListeners();
  }

  Future<void> deleteUploadedPhoto(String url) async {
    final userId = currentUser.id;
    if (userId != 'user_1') {
      try {
        // 1. Önce user_photos'tan sil
        await _supabase.from('user_photos').delete().eq('storage_url', url).eq('user_id', userId);
        
        // 2. Storage yolunu parse et (Query parametrelerini ve URL encoding'i temizle)
        String? storagePath;
        final bucketKeyword = '/avatars/';
        if (url.contains(bucketKeyword)) {
          final index = url.indexOf(bucketKeyword);
          var pathPart = url.substring(index + bucketKeyword.length);
          if (pathPart.contains('?')) {
            pathPart = pathPart.split('?').first;
          }
          storagePath = Uri.decodeComponent(pathPart);
        }
        
        // 3. Storage'dan sil
        if (storagePath != null) {
          debugPrint('Storage silme isteği atılıyor, dosya yolu: $storagePath');
          await _supabase.storage.from('avatars').remove([storagePath]);
        }
      } catch (e) {
        debugPrint('Fotoğraf silme hatası: $e');
        throw Exception('Fotoğraf silinirken hata oluştu: $e');
      }
    }
    
    // Yerel verileri güncelle
    currentUser.avatarUrls.remove(url);
    if (currentUser.avatarUrl == url) {
      currentUser.avatarUrl = currentUser.avatarUrls.isNotEmpty ? currentUser.avatarUrls.first : '';
    }
    _saveProfileData();
    notifyListeners();
  }

  void scatterMockUsersAround(double baseLat, double baseLng) {
    // Bu özellik 'Radar' özelliği test edilebilsin diye diğer kullanıcıları sizin 300-600m çevrenize dağıtır.
    for (var event in _events) {
      for (int i = 0; i < event.attendees.length; i++) {
        double offsetLat = (i % 2 == 0) ? 0.002 : 0.006; 
        double offsetLng = (i % 3 == 0) ? 0.002 : -0.001; 
        
        event.attendees[i].latitude = baseLat + offsetLat;
        event.attendees[i].longitude = baseLng + offsetLng;
      }
    }
    notifyListeners();
  }

  final List<String> activityFeed = [];

  List<String> categories = ['Tümü', '🌟 Sana Özel', '🔥 Popüler', '💖 Eşleşme Oranı Yüksek', 'Konser', 'Tiyatro', 'Stand-up', 'Festival', 'Gece Kulübü'];
  String _selectedCategory = 'Tümü';
  String _searchQuery = '';

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<EventModel> getAdminEvents() => [..._events];

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void addCategory(String category) {
    if (!categories.contains(category)) {
      categories.add(category);
      notifyListeners();
    }
  }

  void addEvent(EventModel event) {
    _events.insert(0, event);
    notifyListeners();
  }

  void updateEvent(EventModel event) {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      _events[index] = event;
      notifyListeners();
    }
  }

  Future<void> importEventsFromExcel(List<int> bytes) async {
    var excel = Excel.decodeBytes(bytes);
    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet == null) continue;

      // Skip header row
      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.row(i);
        if (row.isEmpty) continue;
        
        try {
          final title = row[0]?.value?.toString() ?? '';
          if (title.isEmpty || title == 'null') continue;
          
          final category = row.length > 1 ? row[1]?.value?.toString() ?? 'Diğer' : 'Diğer';
          final location = row.length > 2 ? row[2]?.value?.toString() ?? 'Bilinmeyen Konum' : 'Bilinmeyen Konum';
          
          DateTime dateTime = DateTime.now().add(const Duration(days: 7));
          if (row.length > 3 && row[3]?.value != null) {
            dateTime = DateTime.tryParse(row[3]!.value.toString()) ?? dateTime;
          }

          final description = row.length > 4 ? row[4]?.value?.toString() ?? '' : '';
          final imageUrl = row.length > 5 ? row[5]?.value?.toString() ?? 'assets/images/placeholder.png' : 'assets/images/placeholder.png';
          
          double? lat;
          if (row.length > 6 && row[6]?.value != null) lat = double.tryParse(row[6]!.value.toString());
          
          double? lng;
          if (row.length > 7 && row[7]?.value != null) lng = double.tryParse(row[7]!.value.toString());

          final newEvent = EventModel(
            id: 'e_excel_${DateTime.now().millisecondsSinceEpoch}_$i',
            title: title,
            category: category == 'null' ? 'Diğer' : category,
            location: location == 'null' ? 'Bilinmeyen Konum' : location,
            dateTime: dateTime,
            description: description == 'null' ? '' : description,
            imageUrl: (imageUrl.isEmpty || imageUrl == 'null') ? 'assets/images/placeholder.png' : imageUrl,
            latitude: lat,
            longitude: lng,
            attendees: [],
          );
          
          _events.insert(0, newEvent);
        } catch (e) {
          debugPrint('Error parsing row $i: $e');
        }
      }
    }
    notifyListeners();
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  final List<EventModel> _events = [
    // Ahududu
    EventModel(
      id: 'e_ahududu_1',
      title: 'Ahududu',
      category: 'Tiyatro',
      location: 'İstanbul - Sancaktepe Sahnesi',
      dateTime: DateTime(2026, 6, 8, 20, 0),
      description: 'Türk tiyatrosunun en sevilen komedilerinden Ahududu, usta oyuncu kadrosuyla karşınızda.',
      imageUrl: 'assets/images/ahududu.jpeg',
      latitude: 41.015,
      longitude: 29.023,
      atmosphere: '🔥 Çok Hareketli',
      isPopular: true,
      attendees: [
        UserModel(
          id: 'u2', 
          name: 'Ayşe Yılmaz', 
          avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=100', 
          birthDate: DateTime(2002, 1, 1), 
          aboutMe: 'Sahne sanatları aşığı! Her hafta bir tiyatroya gitmezsem olmaz.', 
          tags: ['Tiyatro', 'Konser', 'Sanat'],
          points: 2100,
          badges: ['Sahne Tozu Yutmuş'],
          plannedEvents: ['e_kacpara_2'], 
          pastEvents: ['e_agaclar_1']
        ),
      ],
    ),
    // Kaç Para Bi Fön
    EventModel(
      id: 'e_kacpara_1',
      title: 'Kaç Para Bi Fön',
      category: 'Tiyatro',
      location: 'İstanbul - Fişekhane',
      dateTime: DateTime(2026, 4, 11, 20, 0),
      description: 'İlişkisini al gel! Çıkışta konuşacak çok şeyiniz olacak.',
      imageUrl: 'assets/images/kac_para_bi_fon.jpeg',
      latitude: 40.985,
      longitude: 28.930,
      atmosphere: '✨ Eğlenceli',
      isPopular: false,
      attendees: [
        UserModel(id: 'u10', name: 'Zeynep', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=100'),
        UserModel(id: 'u11', name: 'Murat', avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=100'),
        UserModel(id: 'u12', name: 'Selin', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=100'),
        UserModel(id: 'u13', name: 'Hakan', avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=100'),
      ],
    ),
    EventModel(
      id: 'e_kacpara_2',
      title: 'Kaç Para Bi Fön',
      category: 'Tiyatro',
      location: 'İstanbul - Akatlar Kültür Merkezi',
      dateTime: DateTime(2026, 4, 17, 20, 0),
      description: 'İlişkisini al gel! Çıkışta konuşacak çok şeyiniz olacak.',
      imageUrl: 'assets/images/kac_para_bi_fon.jpeg',
      latitude: 41.033,
      longitude: 29.030,
      attendees: [],
    ),
    // Baturay Özdemir
    EventModel(
      id: 'e_baturay_1',
      title: 'Baturay Özdemir',
      category: 'Stand-up',
      location: 'İstanbul - Süleyman Seba K.M.',
      dateTime: DateTime(2026, 4, 17, 20, 30),
      description: 'Baturay Özdemir kahkaha dolu gösterisiyle geliyor!',
      imageUrl: 'assets/images/baturay.jpeg',
      latitude: 41.050,
      longitude: 28.990,
      attendees: [],
    ),
    EventModel(
      id: 'e_baturay_2',
      title: 'Baturay Özdemir',
      category: 'Stand-up',
      location: 'İstanbul - DasDas Ataşehir',
      dateTime: DateTime(2026, 4, 22, 20, 30),
      description: 'Baturay Özdemir kahkaha dolu gösterisiyle geliyor!',
      imageUrl: 'assets/images/baturay.jpeg',
      latitude: 40.990,
      longitude: 29.120,
      attendees: [],
    ),
    EventModel(
      id: 'e_baturay_3',
      title: 'Baturay Özdemir',
      category: 'Stand-up',
      location: 'İstanbul - Moi Sahne',
      dateTime: DateTime(2026, 4, 24, 20, 30),
      description: 'Baturay Özdemir kahkaha dolu gösterisiyle geliyor!',
      imageUrl: 'assets/images/baturay.jpeg',
      attendees: [],
    ),
    // Bir Baba Hamlet
    EventModel(
      id: 'e_hamlet_1',
      title: 'Bir Baba Hamlet',
      category: 'Tiyatro',
      location: 'İstanbul - Süleyman Seba K.M.',
      dateTime: DateTime(2026, 4, 24, 20, 0),
      description: 'Şevket Çoruh ve Murat Akkoyunlu\'nun performansıyla muhteşem komedi!',
      imageUrl: 'assets/images/bir_baba_hamlet.jpeg',
      latitude: 41.045,
      longitude: 28.980,
      attendees: [
         UserModel(
           id: 'u4', 
           name: 'Zeynep Kaya', 
           avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=100', 
           birthDate: DateTime(1999, 1, 1), 
           aboutMe: 'Tam bir stand-up bağımlısıyım. Gülmeyi çok seviyorum.', 
           tags: ['Stand-up', 'Spor', 'Müzik'],
           points: 850,
           badges: ['Sinema Sever'],
           plannedEvents: ['e_hamlet_2', 'e_baturay_3'], 
           pastEvents: ['e_diyemedim_2']
         ),
      ],
    ),
    EventModel(
      id: 'e_hamlet_2',
      title: 'Bir Baba Hamlet',
      category: 'Tiyatro',
      location: 'İstanbul - Mall Of İstanbul',
      dateTime: DateTime(2026, 4, 25, 20, 0),
      description: 'Şevket Çoruh ve Murat Akkoyunlu\'nun performansıyla muhteşem komedi!',
      imageUrl: 'assets/images/bir_baba_hamlet.jpeg',
      attendees: [],
    ),
    EventModel(
      id: 'e_hamlet_3',
      title: 'Bir Baba Hamlet',
      category: 'Tiyatro',
      location: 'İstanbul - Beylikdüzü AKM',
      dateTime: DateTime(2026, 4, 26, 20, 0),
      description: 'Şevket Çoruh ve Murat Akkoyunlu\'nun performansıyla muhteşem komedi!',
      imageUrl: 'assets/images/bir_baba_hamlet.jpeg',
      attendees: [],
    ),
    EventModel(
      id: 'e_hamlet_4',
      title: 'Bir Baba Hamlet',
      category: 'Tiyatro',
      location: 'İstanbul - Süleyman Seba K.M.',
      dateTime: DateTime(2026, 5, 14, 20, 0),
      description: 'Şevket Çoruh ve Murat Akkoyunlu\'nun performansıyla muhteşem komedi!',
      imageUrl: 'assets/images/bir_baba_hamlet.jpeg',
      attendees: [],
    ),
    // Diyemedim
    EventModel(
      id: 'e_diyemedim_1',
      title: 'Diyemedim',
      category: 'Tiyatro',
      location: 'Adana - 01 Burda PGM Sahne',
      dateTime: DateTime(2026, 5, 15, 20, 0),
      description: 'Diyemedim adlı oyun, etkileyici hikayesiyle izleyiciyle buluşuyor.',
      imageUrl: 'assets/images/diyemedim.jpeg',
      attendees: [],
    ),
    EventModel(
      id: 'e_diyemedim_2',
      title: 'Diyemedim',
      category: 'Tiyatro',
      location: 'Hatay - İskenderun Ted Koleji',
      dateTime: DateTime(2026, 5, 16, 20, 0),
      description: 'Diyemedim adlı oyun, etkileyici hikayesiyle izleyiciyle buluşuyor.',
      imageUrl: 'assets/images/diyemedim.jpeg',
      attendees: [],
    ),
    EventModel(
      id: 'e_diyemedim_3',
      title: 'Diyemedim',
      category: 'Tiyatro',
      location: 'Gaziantep - Şehit Kamil Bld. K.M.',
      dateTime: DateTime(2026, 5, 17, 20, 0),
      description: 'Diyemedim adlı oyun, etkileyici hikayesiyle izleyiciyle buluşuyor.',
      imageUrl: 'assets/images/diyemedim.jpeg',
      attendees: [],
    ),
    // Ağaçlar Ayakta Ölür
    EventModel(
      id: 'e_agaclar_1',
      title: 'Ağaçlar Ayakta Ölür',
      category: 'Tiyatro',
      location: 'İstanbul - Kenter Tiyatrosu',
      dateTime: DateTime(2026, 5, 20, 20, 0),
      description: 'Ağaçlar Ayakta Ölür, klasikleşmiş metni ve güçlü rejisiyle tiyatro severlerin karşısında.',
      imageUrl: 'assets/images/agaclar_ayakta_olur.jpeg',
      attendees: [],
    ),
  ];

  List<EventModel> get filteredEvents {
    final now = DateTime.now();
    List<EventModel> activeEvents = _events.where((e) => e.isActive && e.dateTime.isAfter(now)).toList();
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      activeEvents = activeEvents.where((e) => 
        e.title.toLowerCase().contains(query) || 
        e.description.toLowerCase().contains(query) || 
        e.location.toLowerCase().contains(query)
      ).toList();
    }
    
    if (_selectedCategory == 'Tümü') return activeEvents;
    
    if (_selectedCategory == '🔥 Popüler') {
      final sorted = List<EventModel>.from(activeEvents)..sort((a,b) => b.attendees.length.compareTo(a.attendees.length));
      return sorted;
    }
    
    if (_selectedCategory == '🌟 Sana Özel') {
      // Kullanıcının ilgi alanlarına (tags) göre filtrele
      return activeEvents.where((e) {
        return currentUser.tags.any((tag) => 
          e.category.toLowerCase().contains(tag.toLowerCase()) ||
          e.title.toLowerCase().contains(tag.toLowerCase())
        );
      }).toList();
    }
    
    if (_selectedCategory == '💖 Eşleşme Oranı Yüksek') {
      // Eşleşme oranı yüksek olanları (katılımcı sayısına göre veya rastgele şimdilik) getir
      return List<EventModel>.from(activeEvents).reversed.toList();
    }
    
    return activeEvents.where((e) => e.category == _selectedCategory).toList();
  }

  void toggleEventVisibility(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _events[index].isActive = !_events[index].isActive;
      notifyListeners();
    }
  }

  EventModel? getEventById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> joinEvent(String eventId) async {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex >= 0) {
      final event = _events[eventIndex];
      bool changed = false;

      // 1. Etkinliğin katılımcılar listesine ekle (yoksa)
      if (!event.attendees.any((u) => u.id == currentUser.id)) {
        event.attendees.add(UserModel(
          id: currentUser.id,
          name: currentUser.name,
          avatarUrl: currentUser.avatarUrl,
          city: currentUser.city,
          birthDate: currentUser.birthDate,
          tags: List.from(currentUser.tags),
        ));
        changed = true;
      }

      // 2. Kullanıcının planlanan etkinlikler listesine ekle (yoksa)
      if (!currentUser.plannedEvents.contains(eventId)) {
        currentUser.plannedEvents.add(eventId);
        _savePlannedEvents(); // Save to preferences locally
        changed = true;

        // Supabase veritabanına kaydet (Gerçek zamanlı Swipe ve Mesajlar için)
        try {
          await _supabase.from('event_attendees').insert({
            'user_id': currentUser.id,
            'event_id': eventId,
            'status': 'joined'
          });
        } catch (e) {
          debugPrint('Supabase event_attendees kayıt hatası: $e');
        }
      }

      if (changed) {
        notifyListeners();
      }
    }
  }

  bool isUserAttending(String eventId) {
     // Check locally specifically for this user's planned events
     return currentUser.plannedEvents.contains(eventId);
  }

  // Get all events
  List<EventModel> get allEvents => _events.where((e) => e.dateTime.isAfter(DateTime.now())).toList();

  bool isUserCheckedIn(String eventId) {
    return currentUser.checkedInEventId == eventId;
  }

  void checkIn(String eventId) {
    currentUser.checkedInEventId = eventId;
    // Puan ekle
    currentUser.points += 50;
    notifyListeners();
  }

  void checkOut() {
    currentUser.checkedInEventId = null;
    notifyListeners();
  }

  final Map<String, List<Map<String, dynamic>>> _venueChats = {};

  List<Map<String, dynamic>> getVenueMessages(String eventId) {
    return _venueChats[eventId] ?? [];
  }

  void sendVenueMessage(String eventId, String message) {
    if (!_venueChats.containsKey(eventId)) {
      _venueChats[eventId] = [];
    }
    _venueChats[eventId]!.add({
      'userId': currentUser.id,
      'userName': currentUser.name,
      'message': message,
      'time': DateTime.now(),
    });
    notifyListeners();
  }

  Map<String, dynamic> calculateVibe(UserModel targetUser) {
    int score = 0;
    List<String> commonalities = [];

    // Tag matching
    final commonTags = currentUser.tags.where((tag) => targetUser.tags.contains(tag)).toList();
    score += commonTags.length * 15;
    if (commonTags.isNotEmpty) {
      commonalities.add('İkiniz de ${commonTags.take(2).join(' ve ')} seviyorsunuz!');
    }

    // Planned events matching
    final commonEvents = currentUser.plannedEvents.where((e) => targetUser.plannedEvents.contains(e)).toList();
    score += commonEvents.length * 20;
    if (commonEvents.isNotEmpty) {
      commonalities.add('İkiniz de aynı etkinliğe gitmeyi planlıyorsunuz!');
    }

    // Past events simulation (Dummy)
    if (targetUser.id.hashCode % 3 == 0) {
      score += 25;
      commonalities.add('Son bir ayda 3 kez aynı tiyatroya gittiniz!');
    }

    // Favorite place simulation (Dummy)
    if (targetUser.name.length % 2 == 0) {
      score += 15;
      commonalities.add('Favori mekanınız aynı halı saha!');
    }

    // Cap score at 99
    if (score > 99) score = 99;
    if (score < 40) score = 40 + (targetUser.id.hashCode % 30); // Minimum vibe

    return {
      'score': score,
      'commonalities': commonalities,
    };
  }}
