import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';

class MockEventService extends ChangeNotifier {
  MockEventService() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    final name = prefs.getString('userName');
    if (name != null) currentUser.name = name;
    final age = prefs.getString('userAge');
    if (age != null) currentUser.age = age;
    final gender = prefs.getString('userGender');
    if (gender != null) currentUser.gender = gender;
    final aboutMe = prefs.getString('userAboutMe');
    if (aboutMe != null) currentUser.aboutMe = aboutMe;
    final socialLinks = prefs.getStringList('userSocialLinks');
    if (socialLinks != null) currentUser.socialLinks = socialLinks;
    final avatarUrl = prefs.getString('userAvatarUrl');
    if (avatarUrl != null) currentUser.avatarUrl = avatarUrl;
    final avatarUrls = prefs.getStringList('userAvatarUrls');
    if (avatarUrls != null) currentUser.avatarUrls = avatarUrls;
    final tags = prefs.getStringList('userTags');
    if (tags != null) currentUser.tags = tags;
    final pastEvents = prefs.getStringList('userPastEvents');
    if (pastEvents != null) currentUser.pastEvents = pastEvents;

    final plannedEvents = prefs.getStringList('plannedEvents');
    if (plannedEvents != null) {
      currentUser.plannedEvents = plannedEvents;
      for (var eventId in plannedEvents) {
        final event = getEventById(eventId);
        if (event != null && !event.attendees.any((u) => u.id == currentUser.id)) {
          event.attendees.add(currentUser);
        }
      }
    }
    notifyListeners();
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', currentUser.name);
    await prefs.setString('userAge', currentUser.age ?? '');
    await prefs.setString('userGender', currentUser.gender ?? '');
    await prefs.setString('userAboutMe', currentUser.aboutMe ?? '');
    await prefs.setStringList('userSocialLinks', currentUser.socialLinks);
    await prefs.setString('userAvatarUrl', currentUser.avatarUrl);
    await prefs.setStringList('userAvatarUrls', currentUser.avatarUrls);
    await prefs.setStringList('userTags', currentUser.tags);
    await prefs.setStringList('plannedEvents', currentUser.plannedEvents);
    await prefs.setStringList('userPastEvents', currentUser.pastEvents);
  }

  Future<void> _savePlannedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('plannedEvents', currentUser.plannedEvents);
  }
  final UserModel currentUser = UserModel(
    id: 'user_1',
    name: 'Ali Rıza',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100',
    avatarUrls: ['https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100'],
    age: '26',
    aboutMe: 'Yeni insanlarla tanışmayı ve yeni etkinlikler keşfetmeyi severim.',
    socialLinks: ['https://instagram.com/eventmatch', 'https://x.com/eventmatch'],
    tags: ['Techno', 'Kahve', 'Gaming'],
    points: 1250,
    badges: ['Sahne Tozu Yutmuş', 'Müzik Tutkunu'],
    plannedEvents: ['e_kacpara_1', 'e_baturay_2'],
    pastEvents: ['e_agaclar_1'],
  );

  void updateCurrentUser({
    required String name,
    required String age,
    String? gender,
    required String aboutMe,
    List<String>? socialLinks,
    required String avatarUrl,
    List<String>? avatarUrls,
    List<String>? tags,
    List<String>? plannedEvents,
    List<String>? pastEvents,
  }) {
    currentUser.name = name;
    currentUser.age = age;
    if (gender != null) currentUser.gender = gender;
    currentUser.aboutMe = aboutMe;
    if (socialLinks != null) currentUser.socialLinks = socialLinks;
    currentUser.avatarUrl = avatarUrl;
    if (avatarUrls != null) {
      currentUser.avatarUrls = avatarUrls;
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
          age: '24', 
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
           age: '27', 
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

  void joinEvent(String eventId) {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex >= 0) {
      final event = _events[eventIndex];
      // Eğer zaten katılmamışsa ekle
      if (!event.attendees.any((u) => u.id == currentUser.id)) {
        event.attendees.add(currentUser);
        if (!currentUser.plannedEvents.contains(eventId)) {
          currentUser.plannedEvents.add(eventId);
          _savePlannedEvents(); // Save to preferences
        }
        notifyListeners();
      }
    }
  }

  bool isUserAttending(String eventId) {
     final event = getEventById(eventId);
     if (event == null) return false;
     return event.attendees.any((u) => u.id == currentUser.id);
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
