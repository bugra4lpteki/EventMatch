import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';

class MockMessageService extends ChangeNotifier {
  final MockEventService _eventService;
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  MockMessageService(this._eventService) {
    reloadChats();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        reloadChats();
      } else {
        _chats.clear();
        notifyListeners();
      }
    });
  }

  List<ChatModel> _chats = [];

  List<ChatModel> get individualChats => _chats;
  List<ChatModel> get eventChats => [];

  Future<void> reloadChats() async {
    await _loadChatsFromSupabase();
  }

  Future<void> _loadChatsFromSupabase() async {
    try {
      final currentId = currentUserId;
      if (currentId.isEmpty) return;

      debugPrint('[MessageService] 🔍 reloadChats for user: $currentId');

      // 1. matches tablosundan status = matched olan kayıtları çek
      final matchesRes = await _supabase
          .from('matches')
          .select('*, messages(*)')
          .eq('status', 'matched')
          .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');

      debugPrint('[MessageService] Bulunan matched sayısı: ${matchesRes.length}');

      // 2. Karşı tarafın ID'lerini topla
      final otherUserIds = matchesRes.map((match) {
        final u1 = match['user_id_1'].toString();
        final u2 = match['user_id_2'].toString();
        return u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1;
      }).toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      Map<String, String> photosMap = {};
      Map<String, List<String>> socialLinksMap = {};

      if (otherUserIds.isNotEmpty) {
        // 3. Karşı profillerin isimlerini çek
        try {
          final profilesResList = await _supabase
              .from('users')
              .select('id, name, username, bio, city, gender, interests')
              .inFilter('id', otherUserIds);

          for (var p in profilesResList) {
            profilesMap[p['id'].toString()] = p;
          }
        } catch (e) {
          debugPrint('[MessageService] ⚠️ users sorgu hatası: $e');
        }

        // 4. Profil fotoğraflarını çek
        try {
          final photosRes = await _supabase
              .from('user_photos')
              .select('user_id, storage_url')
              .inFilter('user_id', otherUserIds)
              .eq('is_active', true);

          for (var photo in photosRes) {
            final uId = photo['user_id'].toString();
            if (!photosMap.containsKey(uId)) {
              photosMap[uId] = photo['storage_url'].toString();
            }
          }
        } catch (e) {
          debugPrint('[MessageService] ⚠️ user_photos sorgu hatası: $e');
        }

        // 5. Sosyal medya bağlantılarını çek
        try {
          final socialRes = await _supabase
              .from('user_social_links')
              .select('user_id, url')
              .inFilter('user_id', otherUserIds);

          for (var link in socialRes) {
            final uId = link['user_id'].toString();
            final url = link['url'].toString();
            socialLinksMap.putIfAbsent(uId, () => []).add(url);
          }
        } catch (e) {
          debugPrint('[MessageService] ⚠️ user_social_links sorgu hatası: $e');
        }
      }

      final newChatsList = <ChatModel>[];

      for (var match in matchesRes) {
        final matchId = match['id'].toString();
        final u1 = match['user_id_1'].toString();
        final u2 = match['user_id_2'].toString();
        final otherUserId = u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1;
        final eventId = match['event_id']?.toString();

        final profile = profilesMap[otherUserId];
        final name = profile?['name'] ?? 'Kullanıcı $otherUserId';
        final username = profile?['username'];
        final bio = profile?['bio'];
        final city = profile?['city'];
        final gender = profile?['gender'];
        final avatarUrl = photosMap[otherUserId] ??
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600';

        List<String> socialLinks = List<String>.from(socialLinksMap[otherUserId] ?? []);

        List<String> tags = [];
        if (profile?['interests'] != null) {
          if (profile!['interests'] is List) {
            tags = List<String>.from(profile['interests'] as List);
          }
        }

        final participant = UserModel(
          id: otherUserId,
          name: name,
          username: username,
          avatarUrl: avatarUrl,
          aboutMe: bio,
          city: city,
          gender: gender,
          tags: tags,
          socialLinks: socialLinks,
        );

        final event = eventId != null ? _eventService.getEventById(eventId) : null;

        List<MessageModel> messages = [];
        if (match['messages'] != null && match['messages'] is List) {
          for (var msg in match['messages']) {
            messages.add(MessageModel(
              id: msg['id'].toString(),
              senderId: msg['sender_id'].toString(),
              text: msg['content']?.toString() ?? '',
              timestamp: msg['created_at'] != null
                  ? DateTime.parse(msg['created_at'].toString())
                  : DateTime.now(),
            ));
          }
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        DateTime? expiresAt;
        if (match['expires_at'] != null) {
          expiresAt = DateTime.tryParse(match['expires_at'].toString());
        }

        newChatsList.add(ChatModel(
          id: matchId,
          participant: participant,
          isEventBased: event != null,
          relatedEvent: event,
          unreadCount: 0,
          messages: messages,
          expiresAt: expiresAt,
        ));
      }

      newChatsList.sort((a, b) {
        final aTime = a.messages.isNotEmpty ? a.messages.last.timestamp : DateTime(2000);
        final bTime = b.messages.isNotEmpty ? b.messages.last.timestamp : DateTime(2000);
        return bTime.compareTo(aTime);
      });

      _chats = newChatsList;
      notifyListeners();
    } catch (e) {
      debugPrint('Load Chats Error: $e');
    }
  }

  /// Eşleşilen kullanıcı için sohbet döndürür veya oluşturur
  ChatModel createOrGetChatForUser(UserModel user) {
    final existingIndex = _chats.indexWhere((c) => c.participant.id == user.id);
    if (existingIndex >= 0) {
      return _chats[existingIndex];
    }

    final newChat = ChatModel(
      id: 'chat_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      participant: user,
      isEventBased: true,
      unreadCount: 0,
      messages: [
        MessageModel(
          id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
          senderId: user.id,
          text: 'Harika, eşleştik! 🎉 Ne zaman etkinliğe gidiyoruz?',
          timestamp: DateTime.now(),
        )
      ],
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

    _chats.insert(0, newChat);
    notifyListeners();
    return newChat;
  }

  Future<void> sendMessage(String chatId, String text) async {
    try {
      final currentId = currentUserId;
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        final newMsg = MessageModel(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          senderId: currentId,
          text: text,
          timestamp: DateTime.now(),
        );
        chat.messages.add(newMsg);
        notifyListeners();
      }

      if (currentId.isNotEmpty && !chatId.startsWith('chat_')) {
        await _supabase.from('messages').insert({
          'match_id': chatId,
          'sender_id': currentId,
          'content': text
        });
      }
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
