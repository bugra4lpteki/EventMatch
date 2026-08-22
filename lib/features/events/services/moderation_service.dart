import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationService extends ChangeNotifier {
  static final ModerationService _instance = ModerationService._internal();
  factory ModerationService() => _instance;
  ModerationService._internal() {
    _loadBlockedUsers();
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  final Set<String> _blockedUserIds = {};

  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  Future<void> _loadBlockedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('blocked_user_ids') ?? [];
      _blockedUserIds.addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> blockUser(String userId, {String? userName}) async {
    if (userId.isEmpty) return;
    _blockedUserIds.add(userId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
    } catch (_) {}

    // Persist to Supabase if authenticated
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await _supabase.from('user_blocks').upsert({
          'blocker_id': currentUserId,
          'blocked_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<void> unblockUser(String userId) async {
    if (!_blockedUserIds.contains(userId)) return;
    _blockedUserIds.remove(userId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
    } catch (_) {}

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await _supabase
            .from('user_blocks')
            .delete()
            .match({'blocker_id': currentUserId, 'blocked_id': userId});
      }
    } catch (_) {}
  }

  Future<bool> reportUser({
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
    String? details,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id ?? 'guest_user';
      
      // Save report in Supabase
      try {
        await _supabase.from('user_reports').insert({
          'reporter_id': currentUserId,
          'reported_user_id': reportedUserId,
          'reported_user_name': reportedUserName,
          'reason': reason,
          'details': details ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'status': 'pending_review',
        });
      } catch (_) {}

      // Automatically offer to block the user as well for safety
      await blockUser(reportedUserId, userName: reportedUserName);
      return true;
    } catch (e) {
      debugPrint('[ModerationService] Error reporting user: $e');
      return false;
    }
  }
}
