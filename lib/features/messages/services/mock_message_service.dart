import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';

class MockMessageService extends ChangeNotifier {
  final MockEventService _eventService;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String get currentUserId => _supabase.auth.currentUser?.id ?? 'user_1';
  
  MockMessageService(this._eventService) {
    _loadChatsFromSupabase();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _loadChatsFromSupabase();
      } else {
        _chats.clear();
        notifyListeners();
      }
    });
  }

  List<ChatModel> _chats = [];

  List<ChatModel> get individualChats => _chats;
  List<ChatModel> get eventChats => []; // Or filter based on your needs

  Future<void> _loadChatsFromSupabase() async {
    try {
      if (_supabase.auth.currentUser == null) return;

      // 1. matches tablosundan status = matched ve user_id_1 veya user_id_2 senin ID'n olan kayıtları çek
      final matchesRes = await _supabase.from('matches')
          .select('*, messages(*)')
          .eq('status', 'matched')
          .or('user_id_1.eq.$currentUserId,user_id_2.eq.$currentUserId');

      _chats.clear();

      // 2. Her eşleşme için karşı kişinin ID'sini bul
      final otherUserIds = matchesRes.map((match) {
        return match['user_id_1'] == currentUserId ? match['user_id_2'] : match['user_id_1'];
      }).map((id) => id.toString()).toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      Map<String, String> photosMap = {};

      if (otherUserIds.isNotEmpty) {
        // 3. O ID ile user_profiles view'ından isim ve kullanıcı adını al
        // Kolon yapısını otomatik tespit et
        List<Map<String, dynamic>> profilesResList = [];
        String idCol = 'id';
        try {
          final sample = await _supabase.from('user_profiles').select().limit(1);
          if (sample.isNotEmpty) {
            final cols = sample.first.keys.toList();
            if (!cols.contains('id') && cols.contains('user_id')) {
              idCol = 'user_id';
            }
          }
          profilesResList = await _supabase.from('user_profiles')
              .select('$idCol, name, username')
              .inFilter(idCol, otherUserIds);
        } catch (_) {}
        
        for (var p in profilesResList) {
          profilesMap[p[idCol].toString()] = p;
        }

        // 4. Aynı ID ile user_photos tablosuna istek at, sadece sort_order = 0 olan ilk fotoğrafı al
        final photosRes = await _supabase.from('user_photos')
            .select('user_id, storage_url')
            .inFilter('user_id', otherUserIds)
            .eq('sort_order', 0);
        
        for (var photo in photosRes) {
          photosMap[photo['user_id'].toString()] = photo['storage_url'].toString();
        }
      }

      for (var match in matchesRes) {
        final matchId = match['id'];
        final otherUserId = match['user_id_1'] == currentUserId ? match['user_id_2'] : match['user_id_1'];
        final eventId = match['event_id'];

        final profile = profilesMap[otherUserId];
        final name = profile?['name'] ?? 'Kullanıcı $otherUserId';
        final username = profile?['username'];

        final avatarUrl = photosMap[otherUserId] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=100';

        final participant = UserModel(
          id: otherUserId,
          name: name,
          username: username,
          avatarUrl: avatarUrl,
        );

        final event = _eventService.getEventById(eventId);

        List<MessageModel> messages = [];
        if (match['messages'] != null) {
          for (var msg in match['messages']) {
            messages.add(MessageModel(
              id: msg['id'],
              senderId: msg['sender_id'],
              text: msg['content'],
              timestamp: DateTime.parse(msg['created_at']),
            ));
          }
          // Sort messages by time
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        // Timer Logic
        DateTime? expiresAt;
        if (match['expires_at'] != null) {
          expiresAt = DateTime.parse(match['expires_at']);
        }

        _chats.add(ChatModel(
          id: matchId,
          participant: participant,
          isEventBased: true,
          relatedEvent: event,
          unreadCount: 0, // Calculate properly if needed
          messages: messages,
          expiresAt: expiresAt,
        ));
      }

      // Sort chats by latest message
      _chats.sort((a, b) {
         final aTime = a.messages.isNotEmpty ? a.messages.last.timestamp : DateTime(2000);
         final bTime = b.messages.isNotEmpty ? b.messages.last.timestamp : DateTime(2000);
         return bTime.compareTo(aTime);
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Load Chats Error: $e');
    }
  }

  Future<void> sendMessage(String chatId, String text) async {
    try {
      // Insert message
      await _supabase.from('messages').insert({
        'match_id': chatId,
        'sender_id': currentUserId,
        'content': text
      });

      // Check if this is the first message to trigger the 10-minute timer
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        if (chat.messages.isEmpty) {
          // It's the first message! Set expires_at
          final expiresAt = DateTime.now().add(const Duration(minutes: 10));
          await _supabase.from('matches').update({
            'expires_at': expiresAt.toIso8601String()
          }).eq('id', chatId);
        }
      }

      // Reload chats to get the latest message (or just add locally for speed)
      _loadChatsFromSupabase();
    } catch (e) {
      debugPrint('Send Message Error: $e');
    }
  }

  void markAsRead(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex >= 0) {
      _chats[chatIndex].unreadCount = 0;
      notifyListeners();
    }
  }
}
