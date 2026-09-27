import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationService extends ChangeNotifier {
  static final ModerationService _instance = ModerationService._internal();
  factory ModerationService() => _instance;
  ModerationService._internal() {
    _loadBlockedUsers();
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
  final Set<String> _blockedUserIds = {};
  final Map<String, String> _blockedUserNames = {};

  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);
  Map<String, String> get blockedUserNames => Map.unmodifiable(_blockedUserNames);

  bool isBlocked(String userId) {
    if (userId.trim().isEmpty) return false;
    final lower = userId.toLowerCase().trim();
    return _blockedUserIds.any((id) => id.toLowerCase().trim() == lower);
  }

  String getBlockedUserName(String userId) {
    final lower = userId.toLowerCase().trim();
    for (var entry in _blockedUserNames.entries) {
      if (entry.key.toLowerCase().trim() == lower) {
        return entry.value;
      }
    }
    return '';
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

      final namesJson = prefs.getString('blocked_user_names');
      if (namesJson != null && namesJson.isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(namesJson);
          decoded.forEach((k, v) {
            if (k.isNotEmpty && v.toString().isNotEmpty) {
              _blockedUserNames[k] = v.toString();
            }
          });
        } catch (_) {}
      }
      notifyListeners();
    } catch (_) {}

    await syncFromSupabase();
  }

  Future<void> syncFromSupabase() async {
    try {
      final client = _supabase;
      if (client == null) return;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) return;

      final res = await client
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

      final idsWithoutNames = <String>[];
      for (var id in _blockedUserIds) {
        if (getBlockedUserName(id).isEmpty) {
          idsWithoutNames.add(id);
        }
      }

      if (idsWithoutNames.isNotEmpty) {
        try {
          final usersRes = await client
              .from('users')
              .select('id, name')
              .inFilter('id', idsWithoutNames);
          for (var u in usersRes) {
            final uId = u['id']?.toString() ?? '';
            final uName = u['name']?.toString() ?? '';
            if (uId.isNotEmpty && uName.isNotEmpty) {
              _blockedUserNames[uId] = uName;
              updated = true;
            }
          }
        } catch (_) {}
      }

      if (updated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
        await prefs.setString('blocked_user_names', jsonEncode(_blockedUserNames));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ModerationService] ⚠️ syncFromSupabase error: $e');
    }
  }

  Future<String> resolveUserName(String userId) async {
    final existing = getBlockedUserName(userId);
    if (existing.isNotEmpty && existing != userId) return existing;

    try {
      final client = _supabase;
      if (client == null) return 'Kullanıcı';
      final u = await client.from('users').select('name').eq('id', userId).maybeSingle();
      final n = u?['name']?.toString();
      if (n != null && n.trim().isNotEmpty) {
        _blockedUserNames[userId] = n.trim();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('blocked_user_names', jsonEncode(_blockedUserNames));
        notifyListeners();
        return n.trim();
      }
    } catch (_) {}
    return 'Kullanıcı';
  }

  Future<void> blockUser(String userId, {String? userName}) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    _blockedUserIds.add(cleanId);
    if (userName != null && userName.trim().isNotEmpty && userName != cleanId) {
      _blockedUserNames[cleanId] = userName.trim();
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
      await prefs.setString('blocked_user_names', jsonEncode(_blockedUserNames));
    } catch (_) {}

    // Persist to Supabase if authenticated
    try {
      final client = _supabase;
      final currentUserId = client?.auth.currentUser?.id;
      if (client != null && currentUserId != null) {
        await client.from('user_blocks').upsert({
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
    _blockedUserNames.remove(cleanId);
    _blockedUserNames.removeWhere((k, v) => k.toLowerCase().trim() == lower);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_user_ids', _blockedUserIds.toList());
      await prefs.setString('blocked_user_names', jsonEncode(_blockedUserNames));
    } catch (_) {}

    try {
      final client = _supabase;
      final currentUserId = client?.auth.currentUser?.id;
      if (client != null && currentUserId != null) {
        await client
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
      final client = _supabase;
      final currentUserId = client?.auth.currentUser?.id ?? 'guest_user';
      
      // Save report in Supabase
      try {
        if (client != null) {
          await client.from('user_reports').insert({
            'reporter_id': currentUserId,
            'reported_user_id': reportedUserId,
            'reported_user_name': reportedUserName,
            'reason': reason,
            'details': details ?? '',
            'created_at': DateTime.now().toIso8601String(),
            'status': 'pending_review',
          });
        }
      } catch (_) {}

      // Automatically block the user as well for safety
      await blockUser(reportedUserId, userName: reportedUserName);
      return true;
    } catch (e) {
      debugPrint('[ModerationService] Error reporting user: $e');
      return false;
    }
  }
}
