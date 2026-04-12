import 'package:flutter/material.dart';
import '../models/match_request.dart';
import '../models/user_model.dart';
import 'mock_event_service.dart';

class MockMatchService extends ChangeNotifier {
  final MockEventService eventService;
  
  MockMatchService(this.eventService);

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
    notifyListeners();
  }

  void acceptRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      _requests[index].status = MatchRequestStatus.accepted;
      notifyListeners();
    }
  }

  void rejectRequest(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      _requests[index].status = MatchRequestStatus.rejected;
      notifyListeners();
    }
  }

  bool hasSentRequest(String eventId, String toUserId) {
    return outgoingRequests.any((r) => r.eventId == eventId && r.toUser.id == toUserId);
  }
}
