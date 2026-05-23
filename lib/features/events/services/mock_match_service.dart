import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_request.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import 'mock_event_service.dart';

class MockMatchService extends ChangeNotifier {
  final MockEventService eventService;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String get currentUserId => _supabase.auth.currentUser?.id ?? 'user_1';

  List<UserModel> _potentialMatches = [];
  bool _isDoubleDateMode = false;
  bool get isDoubleDateMode => _isDoubleDateMode;

  MockMatchService(this.eventService) {
    loadPotentialMatches();
  }

  // --- SUPABASE INTEGRATION ---

  Future<void> loadPotentialMatches() async {
    try {
      if (_supabase.auth.currentUser == null) return;

      // 1. Find events current user is attending
      final myEventsRes = await _supabase.from('event_attendees')
          .select('event_id')
          .eq('user_id', currentUserId)
          .eq('status', 'joined');
      
      if (myEventsRes.isEmpty) return;
      final myEventIds = myEventsRes.map((e) => e['event_id']).toList();

      // 2. Find other users attending those events
      final otherAttendeesRes = await _supabase.from('event_attendees')
          .select('user_id, event_id')
          .inFilter('event_id', myEventIds)
          .neq('user_id', currentUserId)
          .eq('status', 'joined');

      // 3. Find already interacted users (liked or matched or rejected)
      final interactionsRes = await _supabase.from('matches')
          .select('user_id_1, user_id_2')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId');
      
      final interactedUserIds = <String>{};
      for (var row in interactionsRes) {
        interactedUserIds.add(row['user_id_1']);
        interactedUserIds.add(row['user_id_2']);
      }

      // 4. Filter users and fetch their profiles
      // Assuming a profiles table exists or we construct mock UserModel for now
      final potentialUserIds = otherAttendeesRes
          .map((row) => row['user_id'].toString())
          .where((id) => !interactedUserIds.contains(id))
          .toSet();

      _potentialMatches.clear();
      
      // Temporary: If you don't have a profiles table, we create dummy UserModels based on IDs
      // In reality, you'd do: final profilesRes = await _supabase.from('profiles').select().inFilter('id', potentialUserIds.toList());
      for (var id in potentialUserIds) {
        _potentialMatches.add(UserModel(
          id: id,
          name: 'Kullanıcı $id', // Get from profiles
          avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100',
          aboutMe: 'Etkinlikte görüşürüz!',
        ));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Load Potential Matches Error: $e');
    }
  }

  Future<void> swipeRight(UserModel targetUser) async {
    try {
      // Find a shared event id first
      final sharedEvents = await _supabase.from('event_attendees')
          .select('event_id')
          .eq('user_id', targetUser.id)
          .eq('status', 'joined');
      
      // Simple assumption: we just take the first one or a specific one
      String eventId = sharedEvents.isNotEmpty ? sharedEvents.first['event_id'] : 'unknown_event';

      // Did they already like us?
      final existingLike = await _supabase.from('matches')
          .select()
          .eq('user_id_1', targetUser.id)
          .eq('user_id_2', currentUserId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existingLike != null && existingLike['status'] == 'liked') {
        // MATCH!
        await _supabase.from('matches').update({
          'status': 'matched'
        }).eq('id', existingLike['id']);
        
        debugPrint("MATCHED with ${targetUser.name}");
      } else {
        // We like them first
        await _supabase.from('matches').insert({
          'user_id_1': currentUserId,
          'user_id_2': targetUser.id,
          'event_id': eventId,
          'status': 'liked'
        });
      }

      _potentialMatches.removeWhere((u) => u.id == targetUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Right Error: $e');
    }
  }

  Future<void> swipeLeft(UserModel targetUser) async {
    // Insert a 'rejected' status to not see them again (or just leave them in a rejected table)
    // Supabase table matches could support 'rejected' status as well.
    try {
      await _supabase.from('matches').insert({
          'user_id_1': currentUserId,
          'user_id_2': targetUser.id,
          'status': 'rejected'
      });
      _potentialMatches.removeWhere((u) => u.id == targetUser.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Swipe Left Error: $e');
    }
  }

  List<UserModel> getPotentialMatches() => _potentialMatches;

  void toggleDoubleDateMode() {
    _isDoubleDateMode = !_isDoubleDateMode;
    notifyListeners();
  }

  List<GroupModel> getPotentialGroups() => []; // MOCK

  // Placeholder for incoming requests if needed for UI
  List<MatchRequest> get incomingRequests => [];

  // --- COMPATIBILITY METHODS FOR UI ---

  void sendRequest(String eventId, UserModel toUser) {
    swipeRight(toUser);
  }

  void acceptRequest(String requestId) {
    // Implement via Supabase matches update if needed
  }

  void rejectRequest(String requestId) {
    // Implement via Supabase matches update if needed
  }

  bool hasSentRequest(String eventId, String toUserId) {
    // Since Supabase queries are async, we return false here for sync UI building
    // Ideally, the UI should use a FutureBuilder or we cache sent requests locally
    return false; 
  }
}
