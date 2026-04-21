import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_request.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import 'mock_event_service.dart';

class MockMatchService extends ChangeNotifier {
  final MockEventService eventService;
  
  MockMatchService(this.eventService) {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final requestsJson = prefs.getStringList('matchRequests');
    if (requestsJson != null) {
      // Sadece kaydedilmiş istekleri kullanalım
      _requests.clear(); 
      for (var str in requestsJson) {
        try {
          final map = jsonDecode(str);
          final fromUser = _findUserById(map['fromUserId']);
          final toUser = _findUserById(map['toUserId']);
          if (fromUser != null && toUser != null) {
            _requests.add(MatchRequest(
              id: map['id'],
              fromUser: fromUser,
              toUser: toUser,
              eventId: map['eventId'],
              status: MatchRequestStatus.values[map['status']],
            ));
          }
        } catch (e) {
          // JSON parse error, just ignore this item
        }
      }
      notifyListeners();
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final requestsJson = _requests.map((r) => jsonEncode({
      'id': r.id,
      'fromUserId': r.fromUser.id,
      'toUserId': r.toUser.id,
      'eventId': r.eventId,
      'status': r.status.index,
    })).toList();
    await prefs.setStringList('matchRequests', requestsJson);
  }

  UserModel? _findUserById(String id) {
    if (id == eventService.currentUser.id) return eventService.currentUser;
    for (var event in eventService.allEvents) {
      for (var user in event.attendees) {
        if (user.id == id) return user;
      }
    }
    // Dummy return if not found
    return UserModel(id: id, name: 'Bilinmeyen Kullanıcı', avatarUrl: '');
  }

  final List<MatchRequest> _requests = [
    // Sahte bir gelen istek ekleyelim test için
    MatchRequest(
      id: 'req_1',
      fromUser: UserModel(
        id: 'u3', 
        name: 'Can Demir', 
        avatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?auto=format&fit=crop&q=80&w=100'
      ),
      toUser: UserModel(
        id: 'user_1', // Our current user ID from MockEventService
        name: 'Ali Rıza',
        avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100'
      ),
      eventId: 'e1',
    ),
  ];

  List<MatchRequest> get incomingRequests {
    return _requests.where((r) => r.toUser.id == eventService.currentUser.id && r.status == MatchRequestStatus.pending).toList();
  }
  
  List<MatchRequest> get outgoingRequests {
    return _requests.where((r) => r.fromUser.id == eventService.currentUser.id).toList();
  }

  void sendRequest(String eventId, UserModel toUser) {
    _requests.add(
      MatchRequest(
        id: DateTime.now().toString(),
        fromUser: eventService.currentUser,
        toUser: toUser,
        eventId: eventId,
      ),
    );
    _savePrefs();
    notifyListeners();
  }

  void acceptRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      _requests[index].status = MatchRequestStatus.accepted;
      _savePrefs();
      notifyListeners();
    }
  }

  void rejectRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      _requests[index].status = MatchRequestStatus.rejected;
      _savePrefs();
      notifyListeners();
    }
  }

  bool hasSentRequest(String eventId, String toUserId) {
    return outgoingRequests.any((r) => r.eventId == eventId && r.toUser.id == toUserId);
  }

  List<UserModel> getPotentialMatches() {
    final allUsers = <UserModel>[];
    for (var event in eventService.allEvents) {
      allUsers.addAll(event.attendees);
    }
    
    final uniqueUsers = <String, UserModel>{};
    for (var u in allUsers) {
      if (u.id != eventService.currentUser.id) {
        uniqueUsers[u.id] = u;
      }
    }
    
    final filteredUsers = uniqueUsers.values.where((user) {
      final hasInteraction = _requests.any((r) => 
        (r.fromUser.id == eventService.currentUser.id && r.toUser.id == user.id) ||
        (r.fromUser.id == user.id && r.toUser.id == eventService.currentUser.id)
      );
      return !hasInteraction;
    }).toList();
    
    return filteredUsers;
  }

  void swipeRight(UserModel user) {
    // Etkinlikten bağımsız bir eşleşme isteği için dummy bir eventId kullanıyoruz
    // veya ortak bir etkinlik buluyoruz
    String sharedEventId = 'general_match';
    for (var myEvent in eventService.currentUser.plannedEvents) {
      if (user.plannedEvents.contains(myEvent)) {
        sharedEventId = myEvent;
        break;
      }
    }
    
    sendRequest(sharedEventId, user);
  }

  void swipeLeft(UserModel user) {
    // Sola kaydırmayı kaydetmek için sahte bir red isteği ekleyebiliriz veya basitçe yoksayabiliriz
    // Tekrar görünmemesi için red olarak ekliyoruz
    _requests.add(
      MatchRequest(
        id: DateTime.now().toString(),
        fromUser: eventService.currentUser,
        toUser: user,
        eventId: 'general_match',
        status: MatchRequestStatus.rejected, // Sola kaydırıldı
      ),
    );
    _savePrefs();
    notifyListeners();
  }

  bool _isDoubleDateMode = false;
  bool get isDoubleDateMode => _isDoubleDateMode;

  void toggleDoubleDateMode() {
    _isDoubleDateMode = !_isDoubleDateMode;
    notifyListeners();
  }

  List<GroupModel> getPotentialGroups() {
    // Mock data for groups
    return [
      GroupModel(
        id: 'g1',
        name: 'Sinem & Ece',
        groupBio: 'Birlikte tiyatroya gitmeyi çok seviyoruz! 🎭',
        members: [
          UserModel(id: 'u_s1', name: 'Sinem', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=100'),
          UserModel(id: 'u_e1', name: 'Ece', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=100'),
        ],
        commonInterests: ['Tiyatro', 'Kahve'],
      ),
      GroupModel(
        id: 'g2',
        name: 'Burak & Mert',
        groupBio: 'Halı saha maçı sonrası bir şeyler içelim diyoruz. ⚽',
        members: [
          UserModel(id: 'u_b1', name: 'Burak', avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=100'),
          UserModel(id: 'u_m1', name: 'Mert', avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=100'),
        ],
        commonInterests: ['Futbol', 'Pub'],
      ),
    ];
  }
}
