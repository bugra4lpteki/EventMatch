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

  bool isBlocked(String userId) {
    if (userId.trim().isEmpty) return false;
    final lower = userId.toLowerCase().trim();
    return _blockedUserIds.any((id) => id.toLowerCase().trim() == lower);
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('blocked_user_ids') ?? [];
      for (var id in list) {
        if (id.trim().isNotEmpty) {
          _blockedUserIds.add(id.trim());
        }
      }
      notifyListeners();
    } catch (_) {}

    // Also fetch from Supabase user_blocks table (both blocker and blocked directions)
    await syncFromSupabase();
  }

  Future<void> syncFromSupabase() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) return;

      final res = await _supabase
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$currentUserId,blocked_id.eq.$currentUserId');

      bool updated = false;
      for (var row in res) {
        final blocker = (row['blocker_id']?.toString() ?? '').trim();
        final blocked = (row['blocked_id']?.toString() ?? '').trim();
        final target = blocker.toLowerCase() == currentUserId.toLowerCase() ? blocked : blocker;
        if (target.isNotEmpty && !_blockedUserIds.any((id) => id.toLowerCase() == target.toLowerCase())) {
          _blockedUserIds.add(target);
          updated = true;
        }
      }

      if (updated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ModerationService] ⚠️ syncFromSupabase error: $e');
    }
  }

  Future<void> blockUser(String userId, {String? userName}) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    _blockedUserIds.add(cleanId);
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
          'blocked_id': cleanId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  Future<void> unblockUser(String userId) async {
    final cleanId = userId.trim();
    final lower = cleanId.toLowerCase();
    _blockedUserIds.removeWhere((id) => id.toLowerCase().trim() == lower);
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
            .or('and(blocker_id.eq.$currentUserId,blocked_id.eq.$cleanId),and(blocker_id.eq.$cleanId,blocked_id.eq.$currentUserId)');
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
