import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';

class MockEventService extends ChangeNotifier {
  final UserModel currentUser = UserModel(
    id: 'user_1',
    name: 'Ali Rıza',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100',
    age: '26',
    aboutMe: 'Yeni insanlarla tanışmayı ve yeni etkinlikler keşfetmeyi severim.',
    tags: ['Techno', 'Kahve', 'Gaming'],
  );

  void updateCurrentUser({required String name, required String age, required String aboutMe, required String avatarUrl, List<String>? tags}) {
    currentUser.name = name;
    currentUser.age = age;
    currentUser.aboutMe = aboutMe;
    currentUser.avatarUrl = avatarUrl;
    if (tags != null) {
      currentUser.tags = tags;
    }
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

  final List<String> activityFeed = [
    '🔥 Merve "Ahududu" oyununa bilet aldı!',
    '🌟 Caner ilgi alanlarına "Tiyatro" ekledi.',
    '💖 Zeynep ile yüksek eşleşme oranınız var!',
    '🎉 Buğra "Kaç Para Bi Fön" etkinliğine bakıyor.'
  ];

  List<String> categories = ['Tümü', '🌟 Sana Özel', '🔥 Popüler', '💖 Eşleşme Oranı Yüksek', 'Konser', 'Tiyatro', 'Stand-up', 'Festival', 'Gece Kulübü'];
  String _selectedCategory = 'Tümü';

  String get selectedCategory => _selectedCategory;
  List<EventModel> getAdminEvents() => [..._events];

  void setCategory(String category) {
    _selectedCategory = category;
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
      attendees: [
        UserModel(id: 'u2', name: 'Ayşe Yılmaz', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=100', age: '24', aboutMe: 'Sahne sanatları aşığı! Her hafta bir tiyatroya gitmezsem olmaz.'),
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
      attendees: [],
    ),
    EventModel(
      id: 'e_kacpara_2',
      title: 'Kaç Para Bi Fön',
      category: 'Tiyatro',
      location: 'İstanbul - Akatlar Kültür Merkezi',
      dateTime: DateTime(2026, 4, 17, 20, 0),
      description: 'İlişkisini al gel! Çıkışta konuşacak çok şeyiniz olacak.',
      imageUrl: 'assets/images/kac_para_bi_fon.jpeg',
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
      attendees: [
         UserModel(id: 'u4', name: 'Zeynep Kaya', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=100', age: '27', aboutMe: 'Tam bir stand-up bağımlısıyım. Gülmeyi çok seviyorum.'),
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
    final activeEvents = _events.where((e) => e.isActive).toList();
    
    if (_selectedCategory == 'Tümü') return activeEvents;
    
    if (_selectedCategory == '🔥 Popüler') {
      final sorted = List<EventModel>.from(activeEvents)..sort((a,b) => b.attendees.length.compareTo(a.attendees.length));
      return sorted;
    }
    
    if (_selectedCategory == '🌟 Sana Özel' || _selectedCategory == '💖 Eşleşme Oranı Yüksek') {
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
        notifyListeners();
      }
    }
  }

  bool isUserAttending(String eventId) {
     final event = getEventById(eventId);
     if (event == null) return false;
     return event.attendees.any((u) => u.id == currentUser.id);
  }
}
