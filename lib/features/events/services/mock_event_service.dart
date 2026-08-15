import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import 'external_event_service.dart';

class MockEventService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  MockEventService() {
    loadUserProfile();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      _events.clear();
      final now = DateTime.now();

      // 1. ÖNEMLİ: Biletix / Ticketmaster Canlı API'sinden tüm turne ve kategorileri eş zamanlı çek
      try {
        final service = ExternalEventService();
        final results = await Future.wait([
          service.fetchLiveTicketmasterEvents(page: 0, size: 100),
          service.fetchLiveTicketmasterEvents(page: 1, size: 100),
          service.fetchLiveTicketmasterEvents(keyword: 'baturay'),
          service.fetchLiveTicketmasterEvents(keyword: 'duman'),
          service.fetchLiveTicketmasterEvents(keyword: 'levent'),
          service.fetchLiveTicketmasterEvents(keyword: 'teoman'),
          service.fetchLiveTicketmasterEvents(keyword: 'tiyatro'),
          service.fetchLiveTicketmasterEvents(keyword: 'stand up'),
          service.fetchLiveTicketmasterEvents(keyword: 'konser'),
        ]);

        for (var list in results) {
          for (var live in list) {
            if (!_events.any((e) => e.id == live.id)) {
              _events.add(live);
            }
          }
        }
        debugPrint('[EventService] 🎟️ Biletix API canlı tüm turne ve etkinlikler eklendi: ${_events.length}');
      } catch (e) {
        debugPrint('[EventService] Canlı Biletix API çekme hatası: $e');
      }

      // 2. Supabase veritabanındaki etkinlikleri çek ve birleştir
      try {
        final data = await _supabase.from('events').select();
        for (var item in data) {
          final event = EventModel.fromJson(item);
          if (event.dateTime.isAfter(now.subtract(const Duration(days: 1)))) {
            if (!_events.any((e) => e.id == event.id)) {
              _events.add(event);
            }
          }
        }
      } catch (e) {
        debugPrint('[EventService] Supabase Events Error: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Events fetch error: $e');
    }
  }

  Future<void> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    final authUser = _supabase.auth.currentUser;
    final userId = authUser?.id ?? 'user_1';
    currentUser.id = userId;

    // Reset to clean slate first
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
          currentUser.name = userData['name'] ?? authUser?.userMetadata?['name'] ?? 'Yeni Kullanıcı';
        } else {
          currentUser.name = authUser?.userMetadata?['name'] ?? 'Yeni Kullanıcı';
        }
        
        try {
          final photos = await _supabase.from('user_photos').select().eq('user_id', userId).eq('is_active', true).order('sort_order');
          if (photos.isNotEmpty) {
            currentUser.avatarUrls = photos.map((p) => p['storage_url'].toString()).toList();
            currentUser.avatarUrl = currentUser.avatarUrls.first;
          }
        } catch (_) {}

        try {
          final links = await _supabase.from('user_social_links').select().eq('user_id', userId);
          if (links.isNotEmpty) {
            currentUser.socialLinks = links.map((l) => l['url'].toString()).toList();
          }
        } catch (_) {}

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
      currentUser.name = prefs.getString('${userId}_userName') ?? 'Ali Rıza';
      currentUser.username = prefs.getString('${userId}_userUsername') ?? 'aliriza';
      
      final birthDateStr = prefs.getString('${userId}_userBirthDate');
      currentUser.birthDate = birthDateStr != null ? DateTime.tryParse(birthDateStr) : DateTime(1998, 1, 1);

      currentUser.city = prefs.getString('${userId}_userCity') ?? 'İstanbul';
      currentUser.gender = prefs.getString('${userId}_userGender') ?? 'Erkek';
      currentUser.aboutMe = prefs.getString('${userId}_userAbout') ?? 'Konser ve festival sever 🎸';
      currentUser.avatarUrl = prefs.getString('${userId}_userAvatarUrl') ?? 'assets/images/user_avatar.jpg';
      currentUser.avatarUrls = prefs.getStringList('${userId}_userAvatarUrls') ?? [currentUser.avatarUrl];
      currentUser.tags = prefs.getStringList('${userId}_userTags') ?? ['Konser', 'Müzik', 'Tiyatro'];
      currentUser.socialLinks = prefs.getStringList('${userId}_userSocialLinks') ?? [];
      currentUser.plannedEvents = prefs.getStringList('${userId}_userPlannedEvents') ?? ['1'];
      currentUser.pastEvents = prefs.getStringList('${userId}_userPastEvents') ?? ['2', '3'];
    }

    notifyListeners();
  }

  void _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUser.id;

    prefs.setString('${userId}_userName', currentUser.name);
    if (currentUser.username != null) prefs.setString('${userId}_userUsername', currentUser.username!);
    if (currentUser.city != null) prefs.setString('${userId}_userCity', currentUser.city!);
    if (currentUser.gender != null) prefs.setString('${userId}_userGender', currentUser.gender!);
    if (currentUser.aboutMe != null) prefs.setString('${userId}_userAbout', currentUser.aboutMe!);
    if (currentUser.birthDate != null) prefs.setString('${userId}_userBirthDate', currentUser.birthDate!.toIso8601String());
    
    prefs.setString('${userId}_userAvatarUrl', currentUser.avatarUrl);
    prefs.setStringList('${userId}_userAvatarUrls', currentUser.avatarUrls);
    prefs.setStringList('${userId}_userTags', currentUser.tags);
    prefs.setStringList('${userId}_userSocialLinks', currentUser.socialLinks);
    prefs.setStringList('${userId}_userPlannedEvents', currentUser.plannedEvents);
    prefs.setStringList('${userId}_userPastEvents', currentUser.pastEvents);
  }

  void _savePlannedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = currentUser.id;
    prefs.setStringList('${userId}_userPlannedEvents', currentUser.plannedEvents);
  }

  UserModel currentUser = UserModel(
    id: 'user_1',
    name: 'Ali Rıza',
    avatarUrl: 'assets/images/user_avatar.jpg',
    avatarUrls: ['assets/images/user_avatar.jpg'],
    aboutMe: 'Konser ve festival sever 🎸',
    city: 'İstanbul',
    gender: 'Erkek',
    birthDate: DateTime(1998, 1, 1),
    tags: ['Konser', 'Müzik', 'Tiyatro'],
    plannedEvents: ['1'],
    pastEvents: ['2', '3'],
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
          await _supabase.from('users').update({
            'username': username,
            'city': city,
            'gender': gender,
            'bio': aboutMe,
            if (tags != null) 'interests': tags,
          }).eq('id', userId);
        }

        await _supabase.auth.updateUser(UserAttributes(
          data: {'name': name, 'username': username},
        ));

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
                
                await _supabase.storage.from('avatars').uploadBinary(
                  pathInBucket,
                  bytes,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: false,
                    contentType: 'image/jpeg',
                  ),
                );
                
                final publicUrl = _supabase.storage.from('avatars').getPublicUrl(pathInBucket);
                finalAvatarUrls.add(publicUrl);
              } catch (e) {
                finalAvatarUrls.add(item.path);
              }
            }
            photoIndex++;
          }
          
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
    if (tags != null) currentUser.tags = tags;
    if (plannedEvents != null) currentUser.plannedEvents = plannedEvents;
    if (pastEvents != null) currentUser.pastEvents = pastEvents;
    _saveProfileData();
    notifyListeners();
  }

  Future<void> deleteUploadedPhoto(String url) async {
    final userId = currentUser.id;
    if (userId != 'user_1') {
      try {
        await _supabase.from('user_photos').delete().eq('storage_url', url).eq('user_id', userId);
        
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
        
        if (storagePath != null) {
          await _supabase.storage.from('avatars').remove([storagePath]);
        }
      } catch (e) {
        throw Exception('Fotoğraf silinirken hata oluştu: $e');
      }
    }
    
    currentUser.avatarUrls.remove(url);
    if (currentUser.avatarUrl == url) {
      currentUser.avatarUrl = currentUser.avatarUrls.isNotEmpty ? currentUser.avatarUrls.first : '';
    }
    _saveProfileData();
    notifyListeners();
  }

  void scatterMockUsersAround(double baseLat, double baseLng) {
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
  List<String> cities = ['Tüm Şehirler', 'İstanbul', 'Ankara', 'İzmir', 'Antalya', 'Bursa', 'Adana', 'Gaziantep', 'Mersin'];
  
  static const List<String> allTurkishCities = [
    'Tüm Şehirler', 'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
    'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın', 'Batman',
    'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale',
    'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
    'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay',
    'Iğdır', 'Isparta', 'İstanbul', 'İzmir', 'Kahramanmaraş', 'Karabük', 'Karaman',
    'Kars', 'Kastamonu', 'Kayseri', 'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kilis',
    'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla',
    'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun', 'Siirt',
    'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli',
    'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak'
  ];

  String _selectedCategory = 'Tümü';
  String _selectedCity = 'Tüm Şehirler';
  String _searchQuery = '';

  String get selectedCategory => _selectedCategory;
  String get selectedCity => _selectedCity;
  String get searchQuery => _searchQuery;
  List<EventModel> getAdminEvents() => [..._events];

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setCity(String city) {
    _selectedCity = city;
    if (!cities.contains(city)) {
      cities.insert(1, city);
    }
    notifyListeners();

    if (city != 'Tüm Şehirler' && city.trim().isNotEmpty) {
      _searchLiveEvents(city);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();

    if (query.trim().length >= 2 && query.trim().toLowerCase() != 'biletix') {
      _searchLiveEvents(query.trim());
    }
  }

  Future<void> _searchLiveEvents(String query) async {
    try {
      final liveResults = await ExternalEventService().fetchLiveTicketmasterEvents(keyword: query);
      bool addedAny = false;
      for (var live in liveResults) {
        if (!_events.any((e) => e.id == live.id || e.title.toLowerCase() == live.title.toLowerCase())) {
          _events.add(live);
          addedAny = true;
        }
      }
      if (addedAny) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EventService] Live search error: $e');
    }
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
      var sheet = excel.tables[table]!;
      for (var i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty) continue;
        try {
          final title = row[0]?.value?.toString() ?? 'İsimsiz Etkinlik';
          final category = row.length > 1 ? row[1]?.value?.toString() ?? 'Genel' : 'Genel';
          final location = row.length > 2 ? row[2]?.value?.toString() ?? 'İstanbul' : 'İstanbul';
          
          DateTime dateTime = DateTime.now().add(Duration(days: i));
          if (row.length > 3 && row[3]?.value != null) {
            final parsedDate = DateTime.tryParse(row[3]!.value.toString());
            if (parsedDate != null) dateTime = parsedDate;
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

  final List<EventModel> _events = [];
  final Map<String, String> _normalizedTextCache = {};

  String _normalizeText(String input) {
    if (input.isEmpty) return '';
    if (_normalizedTextCache.containsKey(input)) {
      return _normalizedTextCache[input]!;
    }
    final normalized = input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .replaceAll('ı', 'i')
        .toLowerCase()
        .replaceAll('i̇', 'i');
    if (_normalizedTextCache.length > 1000) {
      _normalizedTextCache.clear();
    }
    _normalizedTextCache[input] = normalized;
    return normalized;
  }

  List<EventModel> get filteredEvents {
    final now = DateTime.now();
    List<EventModel> activeEvents = _events.where((e) => e.isActive && e.dateTime.isAfter(now.subtract(const Duration(days: 1)))).toList();

    // 1. Arama sorgusu varsa: Tüm şehirler ve tüm kategoriler genelinde arama yap ve doğrudan döndür!
    if (_searchQuery.trim().isNotEmpty) {
      final rawQuery = _searchQuery.trim();
      final normQuery = _normalizeText(rawQuery);
      final tokens = normQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      return activeEvents.where((e) {
        final title = _normalizeText(e.title);
        final desc = _normalizeText(e.description);
        final loc = _normalizeText(e.location);
        final cat = _normalizeText(e.category);
        final provider = _normalizeText(e.ticketProvider ?? '');
        final ticketUrl = _normalizeText(e.ticketUrl ?? '');

        if (normQuery == 'biletix' || normQuery.contains('biletix')) {
          if (e.id.startsWith('biletix_') || provider.contains('biletix') || ticketUrl.contains('biletix')) {
            return true;
          }
        }

        return tokens.every((token) {
          return title.contains(token) || 
                 desc.contains(token) || 
                 loc.contains(token) || 
                 cat.contains(token) ||
                 provider.contains(token) ||
                 ticketUrl.contains(token);
        });
      }).toList();
    }

    // 2. Arama yapılmıyorsa: Seçili Şehir filtresini uygula
    if (_selectedCity != 'Tüm Şehirler') {
      final cityNorm = _normalizeText(_selectedCity);
      activeEvents = activeEvents.where((e) => _normalizeText(e.location).contains(cityNorm)).toList();
    }
    
    if (_selectedCategory == 'Tümü') return activeEvents;
    
    if (_selectedCategory == '🔥 Popüler') {
      final sorted = List<EventModel>.from(activeEvents)..sort((a,b) => b.attendees.length.compareTo(a.attendees.length));
      return sorted;
    }
    
    if (_selectedCategory == '🌟 Sana Özel') {
      return activeEvents.where((e) {
        return currentUser.tags.any((tag) => 
          _normalizeText(e.category).contains(_normalizeText(tag)) ||
          _normalizeText(e.title).contains(_normalizeText(tag))
        );
      }).toList();
    }
    
    if (_selectedCategory == '💖 Eşleşme Oranı Yüksek') {
      return List<EventModel>.from(activeEvents).reversed.toList();
    }
    
    final selectedNorm = _normalizeText(_selectedCategory);
    return activeEvents.where((e) {
      final catNorm = _normalizeText(e.category);
      if (selectedNorm == 'konser') {
        return catNorm.contains('konser') || catNorm.contains('music') || catNorm.contains('müzik') || catNorm.contains('pop') || catNorm.contains('rock');
      }
      if (selectedNorm == 'tiyatro') {
        return catNorm.contains('tiyatro') || catNorm.contains('theatre') || catNorm.contains('art');
      }
      return catNorm.contains(selectedNorm);
    }).toList();
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

      if (!currentUser.plannedEvents.contains(eventId)) {
        currentUser.plannedEvents.add(eventId);
        _savePlannedEvents();
        changed = true;

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

  Future<void> leaveEvent(String eventId) async {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex >= 0) {
      final event = _events[eventIndex];
      event.attendees.removeWhere((u) => u.id == currentUser.id);
      currentUser.plannedEvents.remove(eventId);
      if (currentUser.checkedInEventId == eventId) {
        currentUser.checkedInEventId = null;
      }
      _savePlannedEvents();

      try {
        await _supabase.from('event_attendees')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('event_id', eventId);
      } catch (e) {
        debugPrint('Supabase event_attendees silme hatası: $e');
      }

      notifyListeners();
    }
  }

  bool isUserAttending(String eventId) {
     return currentUser.plannedEvents.contains(eventId);
  }

  List<EventModel> get allEvents => _events.where((e) => e.dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 6)))).toList();

  bool isUserCheckedIn(String eventId) {
    return currentUser.checkedInEventId == eventId;
  }

  void checkIn(String eventId) {
    currentUser.checkedInEventId = eventId;
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

    final commonTags = currentUser.tags.where((tag) => targetUser.tags.contains(tag)).toList();
    score += commonTags.length * 15;
    if (commonTags.isNotEmpty) {
      commonalities.add('İkiniz de ${commonTags.take(2).join(' ve ')} seviyorsunuz!');
    }

    final commonEvents = currentUser.plannedEvents.where((e) => targetUser.plannedEvents.contains(e)).toList();
    score += commonEvents.length * 30;
    if (commonEvents.isNotEmpty) {
      commonalities.add('Aynı etkinliğe gitmeyi planlıyorsunuz!');
    }

    if (currentUser.city != null && targetUser.city != null &&
        currentUser.city!.trim().isNotEmpty && targetUser.city!.trim().isNotEmpty &&
        currentUser.city!.trim().toLowerCase() == targetUser.city!.trim().toLowerCase()) {
      score += 10;
      commonalities.add('İkiniz de ${currentUser.city!.trim()}\'desiniz.');
    }

    score = score.clamp(35, 98);
    if (commonalities.isEmpty) {
      commonalities.add('Ortak müzik ve etkinlik zevkleriniz var!');
    }

    return {
      'score': score,
      'commonalities': commonalities,
    };
  }

  void clearUserData() {
    currentUser = UserModel(
      id: 'guest',
      name: 'Misafir Kullanıcı',
      avatarUrl: '',
      avatarUrls: [],
      pastEvents: [],
      plannedEvents: [],
      socialLinks: [],
      tags: [],
    );
    notifyListeners();
  }
}
