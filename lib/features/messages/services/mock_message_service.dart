import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';

class MockMessageService extends ChangeNotifier {
  final MockEventService _eventService;
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  final Set<String> _blockedUserIds = {};
  final Set<String> _followingUserIds = {};
  final Set<String> _deletedChatIds = {};

  MockMessageService(this._eventService) {
    reloadChats();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        reloadChats();
      } else {
        _chats.clear();
        _blockedUserIds.clear();
        _followingUserIds.clear();
        _deletedChatIds.clear();
        notifyListeners();
      }
    });
  }

  List<ChatModel> _chats = [];

  List<ChatModel> get individualChats => _chats
      .where((c) => !_deletedChatIds.contains(c.id))
      .toList();

  List<ChatModel> get eventChats => [];

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);
  bool isFollowing(String userId) => _followingUserIds.contains(userId);

  void toggleBlockUser(String userId) {
    if (_blockedUserIds.contains(userId)) {
      _blockedUserIds.remove(userId);
    } else {
      _blockedUserIds.add(userId);
    }
    notifyListeners();
  }

  void toggleFollowUser(String userId) {
    if (_followingUserIds.contains(userId)) {
      _followingUserIds.remove(userId);
    } else {
      _followingUserIds.add(userId);
    }
    notifyListeners();
  }

  Future<void> deleteChat(String chatId) async {
    _deletedChatIds.add(chatId);
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();

    try {
      if (currentUserId.isNotEmpty && !chatId.startsWith('chat_')) {
        await _supabase.from('messages').delete().eq('match_id', chatId);
      }
    } catch (e) {
      debugPrint('[MessageService] Delete chat error: $e');
    }
  }

  Future<void> reloadChats() async {
    await _loadChatsFromSupabase();
  }

  Future<void> _loadChatsFromSupabase() async {
    try {
      final currentId = currentUserId;
      if (currentId.isEmpty) return;

      debugPrint('[MessageService] 🔍 reloadChats for user: $currentId');

      final matchesRes = await _supabase
          .from('matches')
          .select('*, messages(*)')
          .eq('status', 'matched')
          .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');

      debugPrint('[MessageService] Bulunan matched sayısı: ${matchesRes.length}');

      final otherUserIds = <String>{};
      for (var match in matchesRes) {
        final u1 = match['user_id_1'].toString();
        final u2 = match['user_id_2'].toString();
        final otherId = u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1;
        if (otherId.toLowerCase() != currentId.toLowerCase()) {
          otherUserIds.add(otherId);
        }
      }

      Map<String, Map<String, dynamic>> profilesMap = {};
      Map<String, String> photosMap = {};
      Map<String, List<String>> socialLinksMap = {};

      final validUuidList = otherUserIds
          .where((id) => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id))
          .toList();

      if (validUuidList.isNotEmpty) {
        try {
          final profilesResList = await _supabase
              .from('users')
              .select('id, name, username, bio, city, gender, interests')
              .inFilter('id', validUuidList);

          for (var p in profilesResList) {
            profilesMap[p['id'].toString()] = p;
          }
        } catch (e) {
          debugPrint('[MessageService] ⚠️ users sorgu hatası: $e');
        }

        try {
          final photosRes = await _supabase
              .from('user_photos')
              .select('user_id, storage_url')
              .inFilter('user_id', validUuidList)
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

        try {
          final socialRes = await _supabase
              .from('user_social_links')
              .select('user_id, url')
              .inFilter('user_id', validUuidList);

          for (var link in socialRes) {
            final uId = link['user_id'].toString();
            final url = link['url'].toString();
            socialLinksMap.putIfAbsent(uId, () => []).add(url);
          }
        } catch (e) {
          debugPrint('[MessageService] ⚠️ user_social_links sorgu hatası: $e');
        }
      }

      // DEDUPLICATION: Partner ID bazlı tek sohbet odası tutulur
      final Map<String, ChatModel> chatsByPartnerId = {};

      for (var match in matchesRes) {
        final matchId = match['id'].toString();
        final u1 = match['user_id_1'].toString();
        final u2 = match['user_id_2'].toString();
        final otherUserId = u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1;
        
        if (otherUserId.toLowerCase() == currentId.toLowerCase()) continue;

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
        if (profile?['interests'] != null && profile!['interests'] is List) {
          tags = List<String>.from(profile['interests'] as List);
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
        }

        DateTime? expiresAt;
        if (match['expires_at'] != null) {
          expiresAt = DateTime.tryParse(match['expires_at'].toString());
        }

        if (chatsByPartnerId.containsKey(otherUserId)) {
          // Var olan sohbetle mesajları birleştir (Deduplicate)
          final existingChat = chatsByPartnerId[otherUserId]!;
          for (var msg in messages) {
            if (!existingChat.messages.any((m) => m.id == msg.id || (m.text == msg.text && m.timestamp.difference(msg.timestamp).abs().inSeconds < 2))) {
              existingChat.messages.add(msg);
            }
          }
          existingChat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        } else {
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          chatsByPartnerId[otherUserId] = ChatModel(
            id: matchId,
            participant: participant,
            isEventBased: event != null,
            relatedEvent: event,
            unreadCount: 0,
            messages: messages,
            expiresAt: expiresAt,
          );
        }
      }

      final newChatsList = chatsByPartnerId.values.toList();
      newChatsList.sort((a, b) {
        final aTime = a.messages.isNotEmpty ? a.messages.last.timestamp : DateTime(2000);
        final bTime = b.messages.isNotEmpty ? b.messages.last.timestamp : DateTime(2000);
        return bTime.compareTo(aTime);
      });

      _chats = newChatsList;
      notifyListeners();
    } catch (e) {
      debugPrint('Load Chats Error: $e');
      _chats = [];
      notifyListeners();
    }
  }

  /// Eşleşilen kullanıcı için sohbet döndürür veya oluşturur (Deduplication garantili)
  ChatModel createOrGetChatForUser(UserModel user, {String? initialMessage}) {
    // 1. Önce ID veya isim eşleşmesiyle var olan sohbeti bul
    final existingIndex = _chats.indexWhere(
      (c) => c.participant.id == user.id || c.participant.name.toLowerCase() == user.name.toLowerCase(),
    );

    if (existingIndex >= 0) {
      final chat = _chats[existingIndex];
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        final textTrim = initialMessage.trim();
        if (!chat.messages.any((m) => m.text == textTrim)) {
          chat.messages.add(MessageModel(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
            text: textTrim,
            timestamp: DateTime.now(),
          ));
        }
      }
      return chat;
    }

    // 2. Yoksa tek sohbet oluştur
    final firstMsg = (initialMessage != null && initialMessage.trim().isNotEmpty)
        ? initialMessage.trim()
        : 'Harika, eşleştik! 🎉 Ne zaman etkinliğe gidiyoruz?';

    final newChat = ChatModel(
      id: 'chat_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      participant: user,
      isEventBased: true,
      unreadCount: 0,
      messages: [
        MessageModel(
          id: 'msg_welcome_${DateTime.now().millisecondsSinceEpoch}',
          senderId: currentUserId.isNotEmpty ? currentUserId : 'me',
          text: firstMsg,
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
        
        // Engellenmişse mesaj göndermeyi durdur
        if (isBlocked(chat.participant.id)) {
          return;
        }

        final newMsg = MessageModel(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          senderId: currentId,
          text: text,
          timestamp: DateTime.now(),
        );
        chat.messages.add(newMsg);
        notifyListeners();
      }

      if (currentId.isNotEmpty && int.tryParse(chatId) != null) {
        try {
          await _supabase.from('messages').insert({
            'match_id': int.parse(chatId),
            'sender_id': currentId,
            'content': text
          });
        } catch (e) {
          debugPrint('[MessageService] Supabase message insert error: $e');
        }
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
