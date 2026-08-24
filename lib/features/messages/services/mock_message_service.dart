import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';
import '../models/message_model.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';

class MockMessageService extends ChangeNotifier {
  final MockEventService _eventService;
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId {
    final sbId = _supabase.auth.currentUser?.id;
    if (sbId != null && sbId.isNotEmpty) return sbId;
    final sessId = _supabase.auth.currentSession?.user.id;
    if (sessId != null && sessId.isNotEmpty) return sessId;
    final eventUserId = _eventService.currentUser.id;
    if (eventUserId.isNotEmpty) return eventUserId;
    final eventUserName = _eventService.currentUser.name.replaceAll(' ', '_').toLowerCase();
    return eventUserName.isNotEmpty ? 'user_$eventUserName' : 'user_mobile';
  }

  final Set<String> _blockedUserIds = {};
  final Set<String> _followingUserIds = {};
  final Set<String> _deletedChatIds = {};
  
  // Canlı oda stream kontrolcüleri (Persistent StreamController)
  final Map<String, StreamController<List<MessageModel>>> _roomStreamControllers = {};

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _matchesChannel;
  RealtimeChannel? _broadcastChannel;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ChatModel> _chats = [];

  List<ChatModel> get individualChats => _chats
      .where((c) => !_deletedChatIds.contains(c.id) && !_deletedChatIds.contains(c.participant.id) && !c.isArchived)
      .toList();

  List<ChatModel> get archivedChats => _chats
      .where((c) => !_deletedChatIds.contains(c.id) && !_deletedChatIds.contains(c.participant.id) && c.isArchived)
      .toList();

  void toggleArchiveChat(String chatId) {
    final idx = _chats.indexWhere((c) => c.id == chatId || c.participant.id.toLowerCase() == chatId.toLowerCase());
    if (idx >= 0) {
      _chats[idx].isArchived = !_chats[idx].isArchived;
      _saveChatsToLocalStorage();
      notifyListeners();
    }
  }

  void toggleMuteChat(String chatId) {
    final idx = _chats.indexWhere((c) => c.id == chatId || c.participant.id.toLowerCase() == chatId.toLowerCase());
    if (idx >= 0) {
      _chats[idx].isMuted = !_chats[idx].isMuted;
      _saveChatsToLocalStorage();
      notifyListeners();
    }
  }

  List<ChatModel> get eventChats => [];

  MockMessageService(this._eventService) {
    _initService();
  }

  Future<void> _initService() async {
    await _loadChatsFromLocalStorage();
    await reloadChats();
    _subscribeToRealtime();

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        await _loadChatsFromLocalStorage();
        await reloadChats();
        _subscribeToRealtime();
      } else {
        _unsubscribeFromRealtime();
        _chats.clear();
        _blockedUserIds.clear();
        _followingUserIds.clear();
        _deletedChatIds.clear();
        notifyListeners();
      }
    });
  }

  // --- HİBRİT REACTIVE STREAM + CONTROLLER MOTORU ---

  Stream<List<MessageModel>> getMessagesStream(String partnerId) {
    final lowerPartnerId = partnerId.toLowerCase();
    
    if (!_roomStreamControllers.containsKey(lowerPartnerId) || _roomStreamControllers[lowerPartnerId]!.isClosed) {
      _roomStreamControllers[lowerPartnerId] = StreamController<List<MessageModel>>.broadcast();
    }

    final chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartnerId);
    final initialList = chatIndex >= 0 ? List<MessageModel>.from(_chats[chatIndex].messages) : <MessageModel>[];

    scheduleMicrotask(() {
      if (_roomStreamControllers.containsKey(lowerPartnerId) && !_roomStreamControllers[lowerPartnerId]!.isClosed) {
        _roomStreamControllers[lowerPartnerId]!.add(initialList);
      }
      syncChatMessagesForPartner(partnerId);
    });

    return _roomStreamControllers[lowerPartnerId]!.stream;
  }

  void _emitRoomUpdate(String partnerId) {
    final lowerPartnerId = partnerId.toLowerCase();
    final chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartnerId);
    if (chatIndex >= 0) {
      final freshList = List<MessageModel>.from(_chats[chatIndex].messages);
      if (_roomStreamControllers.containsKey(lowerPartnerId) && !_roomStreamControllers[lowerPartnerId]!.isClosed) {
        _roomStreamControllers[lowerPartnerId]!.add(freshList);
      }
    }
  }

  // --- LOCAL CACHING ---

  String _getCacheKey() {
    final id = currentUserId;
    return id.isNotEmpty ? 'eventmatch_chats_cache_$id' : 'eventmatch_chats_cache_default';
  }

  Future<void> _loadChatsFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final jsonStr = prefs.getString(cacheKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(jsonStr);
        final loadedChats = <ChatModel>[];

        for (var item in decodedList) {
          try {
            loadedChats.add(ChatModel.fromMap(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('MODEL PARSE HATASI: $e');
          }
        }

        if (loadedChats.isNotEmpty) {
          _chats = loadedChats;
          _sortChats();
          notifyListeners();
          for (var chat in _chats) {
            _emitRoomUpdate(chat.participant.id);
          }
          debugPrint('[MessageService] 💾 Yerel önbellekten ${_chats.length} sohbet yüklendi.');
        }
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Local storage read error: $e');
    }
  }

  Future<void> _saveChatsToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final serializedList = _chats.map((c) => c.toMap()).toList();
      await prefs.setString(cacheKey, jsonEncode(serializedList));
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Local storage save error: $e');
    }
  }

  // --- REALTIME ENGINE ---

  void _subscribeToRealtime() {
    try {
      _unsubscribeFromRealtime();

      // 1. Instant WebSocket Broadcast Channel
      _broadcastChannel = _supabase
          .channel('eventmatch_global_chat')
          .onBroadcast(
            event: 'new_message',
            callback: (payload) {
              _handleBroadcastMessage(payload);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 [SUPABASE REALTIME] Broadcast kanalı durumu: $status');
          });

      // 2. Postgres CDC Stream (Realtime Replication)
      _messagesChannel = _supabase
          .channel('public_messages_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              _handlePostgresMessageEvent(payload);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 [SUPABASE REALTIME] Messages CDC akışı durumu: $status');
          });

      // 3. Matches Stream
      _matchesChannel = _supabase
          .channel('public_matches_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            callback: (payload) {
              debugPrint('[MessageService] 🔔 Realtime match change detected');
              reloadChats();
            },
          )
          .subscribe();

      debugPrint('[MessageService] 🚀 Multi-layer realtime kanalları aktif.');
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Realtime subscription error: $e');
    }
  }

  void _unsubscribeFromRealtime() {
    try {
      _broadcastChannel?.unsubscribe();
      _broadcastChannel = null;
      _messagesChannel?.unsubscribe();
      _messagesChannel = null;
      _matchesChannel?.unsubscribe();
      _matchesChannel = null;
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Unsubscribe error: $e');
    }
  }

  void _handleBroadcastMessage(Map<String, dynamic> payload) {
    try {
      final senderId = (payload['sender_id']?.toString() ?? '').toLowerCase();
      final receiverId = (payload['receiver_id']?.toString() ?? '').toLowerCase();
      final content = payload['content']?.toString() ?? '';
      final msgId = payload['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final createdAtStr = payload['created_at']?.toString();
      final timestamp = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

      if (content.trim().isEmpty) return;

      final currentId = currentUserId.toLowerCase();

      String partnerId = '';
      if (senderId == currentId && receiverId.isNotEmpty) {
        partnerId = receiverId;
      } else if (receiverId == currentId || receiverId.isEmpty || receiverId == 'user_mobile') {
        partnerId = senderId;
      } else {
        partnerId = senderId;
      }

      if (partnerId.isEmpty) return;
      if (isBlocked(partnerId) || isBlocked(senderId)) return;

      _injectMessageIntoChat(
        partnerId: partnerId,
        msgId: msgId,
        senderId: payload['sender_id']?.toString() ?? senderId,
        receiverId: payload['receiver_id']?.toString() ?? receiverId,
        content: content,
        timestamp: timestamp,
      );

      if (senderId != currentId) {
        final chat = _chats.firstWhere((c) => c.participant.id.toLowerCase() == partnerId,
            orElse: () => createOrGetChatForUser(UserModel(id: partnerId, name: 'Yeni Mesaj', avatarUrl: '')));
        NotificationService().showMessageNotification(
          chatId: partnerId,
          senderName: chat.participant.name,
          message: content,
        );
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handleBroadcastMessage error: $e');
    }
  }

  void _handlePostgresMessageEvent(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record.isEmpty) return;

      final senderId = (record['sender_id']?.toString() ?? '').toLowerCase();
      final receiverId = (record['receiver_id']?.toString() ?? '').toLowerCase();
      final matchId = record['match_id']?.toString() ?? record['m_id']?.toString() ?? record['M_ID']?.toString();
      final content = record['content']?.toString() ?? record['message']?.toString() ?? '';
      final msgId = record['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final createdAtStr = record['created_at']?.toString();
      final timestamp = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

      if (content.trim().isEmpty) return;

      final currentId = currentUserId.toLowerCase();

      String partnerId = '';
      if (senderId == currentId && receiverId.isNotEmpty) {
        partnerId = receiverId;
      } else if (receiverId == currentId || receiverId.isEmpty || receiverId == 'user_mobile') {
        partnerId = senderId;
      } else if (matchId != null) {
        final matchedChatIndex = _chats.indexWhere((c) => c.id == matchId);
        if (matchedChatIndex >= 0) {
          partnerId = _chats[matchedChatIndex].participant.id.toLowerCase();
        } else {
          partnerId = senderId;
        }
      } else {
        partnerId = senderId;
      }

      if (partnerId.isEmpty) return;
      if (isBlocked(partnerId) || isBlocked(senderId)) return;

      _injectMessageIntoChat(
        partnerId: partnerId,
        msgId: msgId,
        senderId: record['sender_id']?.toString() ?? senderId,
        receiverId: record['receiver_id']?.toString() ?? receiverId,
        content: content,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handlePostgresMessage error: $e');
    }
  }

  void _injectMessageIntoChat({
    required String partnerId,
    required String msgId,
    required String senderId,
    required String receiverId,
    required String content,
    required DateTime timestamp,
  }) {
    if (content.trim().isEmpty || partnerId.isEmpty) return;

    final lowerPartnerId = partnerId.toLowerCase();
    int chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartnerId);

    if (chatIndex < 0) {
      final newChat = createOrGetChatForUser(UserModel(id: partnerId, name: 'Kullanıcı $partnerId', avatarUrl: ''));
      chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == lowerPartnerId);
    }

    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];
      final exists = chat.messages.any((m) =>
          m.id == msgId ||
          (m.text == content && m.senderId.toLowerCase() == senderId.toLowerCase() && m.timestamp.difference(timestamp).abs().inSeconds < 3));

      if (!exists) {
        final newMsg = MessageModel(
          id: msgId,
          senderId: senderId,
          receiverId: receiverId,
          text: content,
          timestamp: timestamp,
          status: MessageStatus.delivered,
        );
        chat.messages.add(newMsg);
        chat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (senderId.toLowerCase() != currentUserId.toLowerCase()) {
          chat.unreadCount += 1;
          if (!chat.isMuted) {
            NotificationService().showMessageNotification(
              chatId: partnerId,
              senderName: chat.participant.name,
              message: content,
              unreadCount: chat.unreadCount,
            );
          }
        }
        _sortChats();
        _saveChatsToLocalStorage();
        _emitRoomUpdate(partnerId);
        notifyListeners();
      }
    }
  }

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

  Future<void> endMatchAndRemoveChat(String chatId, String partnerId) async {
    final lowerPartnerId = partnerId.toLowerCase();
    _chats.removeWhere((c) => c.id == chatId || c.participant.id.toLowerCase() == lowerPartnerId);
    _deletedChatIds.remove(chatId);
    _deletedChatIds.remove(lowerPartnerId);
    _saveChatsToLocalStorage();
    _emitRoomUpdate(partnerId);
    notifyListeners();

    try {
      final currentId = currentUserId;
      if (currentId.isNotEmpty) {
        // 1. Karşılıklı mesajları sil
        await _supabase
            .from('messages')
            .delete()
            .or('and(sender_id.eq.$currentId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$currentId)');

        // 2. Karşılıklı eşleşme kaydını sil
        await _supabase
            .from('matches')
            .delete()
            .or('and(user_id_1.eq.$currentId,user_id_2.eq.$partnerId),and(user_id_1.eq.$partnerId,user_id_2.eq.$currentId)');

        if (int.tryParse(chatId) != null) {
          await _supabase.from('messages').delete().eq('match_id', int.parse(chatId));
          await _supabase.from('matches').delete().eq('id', int.parse(chatId));
        }
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ endMatchAndRemoveChat error: $e');
    }
  }

  Future<void> deleteChat(String chatId) async {
    _deletedChatIds.add(chatId);
    final removed = _chats.where((c) => c.id == chatId).toList();
    _chats.removeWhere((c) => c.id == chatId);
    _saveChatsToLocalStorage();
    notifyListeners();

    try {
      final currentId = currentUserId;
      if (currentId.isNotEmpty) {
        for (var c in removed) {
          _deletedChatIds.add(c.participant.id);
          _emitRoomUpdate(c.participant.id);
        }
        if (int.tryParse(chatId) != null) {
          await _supabase.from('messages').delete().eq('match_id', int.parse(chatId));
          await _supabase.from('matches').delete().eq('id', int.parse(chatId));
        }
      }
    } catch (e) {
      debugPrint('[MessageService] Delete chat error: $e');
    }
  }

  Future<void> reloadChats() async {
    await _loadChatsFromSupabase();
  }

  ChatModel getOrCreateChatRoom(UserModel targetUser, {String? initialMessage}) {
    return createOrGetChatForUser(targetUser, initialMessage: initialMessage);
  }

  ChatModel createOrGetChatForUser(UserModel user, {String? initialMessage}) {
    final lowerUserId = user.id.toLowerCase();
    final existingIndex = _chats.indexWhere(
      (c) => c.participant.id.toLowerCase() == lowerUserId || c.participant.name.toLowerCase() == user.name.toLowerCase(),
    );

    if (existingIndex >= 0) {
      final chat = _chats[existingIndex];
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        final textTrim = initialMessage.trim();
        if (!chat.messages.any((m) => m.text == textTrim)) {
          sendMessage(chat.id, textTrim, receiverUserId: user.id);
        }
      }
      return chat;
    }

    final newChat = ChatModel(
      id: 'chat_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      participant: user,
      isEventBased: true,
      unreadCount: 0,
      messages: [],
    );

    if (initialMessage != null && initialMessage.trim().isNotEmpty) {
      final firstMsg = MessageModel(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: currentUserId.isNotEmpty ? currentUserId : 'user_mobile',
        receiverId: user.id,
        text: initialMessage.trim(),
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
      newChat.messages.add(firstMsg);
    }

    _chats.insert(0, newChat);
    _saveChatsToLocalStorage();
    _emitRoomUpdate(user.id);
    notifyListeners();

    if (initialMessage != null && initialMessage.trim().isNotEmpty) {
      _persistMessage(newChat.id, user.id, initialMessage.trim(), 'msg_${DateTime.now().millisecondsSinceEpoch}');
    }

    return newChat;
  }

  // --- SMART BACKGROUND SYNC (CANLI ANLIK SENKRONİZASYON) ---
  Future<void> syncChatMessagesForPartner(String partnerId) async {
    final currentId = currentUserId;
    if (partnerId.isEmpty) return;

    try {
      final lowerCurrent = currentId.toLowerCase();
      final lowerPartner = partnerId.toLowerCase();

      final res = await _supabase
          .from('messages')
          .select('*')
          .or('sender_id.eq.$currentId,receiver_id.eq.$currentId,sender_id.eq.$partnerId,receiver_id.eq.$partnerId')
          .order('created_at', ascending: true);

      int chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartner);
      if (chatIndex < 0) {
        final newChat = createOrGetChatForUser(UserModel(id: partnerId, name: 'Kullanıcı', avatarUrl: ''));
        chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == lowerPartner);
      }

      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        bool hasNew = false;

        for (var row in res) {
          try {
            final s = (row['sender_id']?.toString() ?? '').toLowerCase();
            final r = (row['receiver_id']?.toString() ?? '').toLowerCase();

            final isForThisChat = (s == lowerCurrent && r == lowerPartner) ||
                                  (s == lowerPartner && r == lowerCurrent) ||
                                  (s == lowerPartner || r == lowerPartner);

            if (!isForThisChat) continue;

            final mId = row['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
            final text = row['content']?.toString() ?? row['message']?.toString() ?? '';
            final sender = row['sender_id']?.toString() ?? '';
            final receiver = row['receiver_id']?.toString() ?? '';
            final ts = row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now() : DateTime.now();

            if (text.trim().isEmpty) continue;

            final existingMsgIndex = chat.messages.indexWhere((m) =>
                m.id == mId ||
                (m.text == text && m.senderId.toLowerCase() == sender.toLowerCase() && m.timestamp.difference(ts).abs().inSeconds < 3));

            if (existingMsgIndex < 0) {
              chat.messages.add(MessageModel(
                id: mId,
                senderId: sender,
                receiverId: receiver,
                text: text,
                timestamp: ts,
                status: MessageStatus.delivered,
              ));
              hasNew = true;
            }
          } catch (e) {
            debugPrint('MODEL PARSE HATASI: $e');
          }
        }

        chat.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (hasNew) {
          _sortChats();
          _saveChatsToLocalStorage();
        }
        _emitRoomUpdate(partnerId);
        if (hasNew) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[MessageService] syncChatMessagesForPartner error: $e');
    }
  }

  bool _isValidUuid(String str) {
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(str);
  }

  Future<void> _loadChatsFromSupabase() async {
    try {
      final currentId = currentUserId;
      if (currentId.isEmpty) return;

      _isLoading = true;

      List<dynamic> matchesRes = [];
      try {
        matchesRes = await _supabase
            .from('matches')
            .select('*, messages(*)')
            .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');
      } catch (e) {
        try {
          matchesRes = await _supabase
              .from('matches')
              .select('*')
              .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId');
        } catch (_) {}
      }

      List<dynamic> directMessagesRes = [];
      try {
        directMessagesRes = await _supabase
            .from('messages')
            .select('*')
            .or('sender_id.eq.$currentId,receiver_id.eq.$currentId')
            .order('created_at', ascending: true);
      } catch (e) {
        debugPrint('[MessageService] ⚠️ direct messages select error: $e');
      }

      final partnerUserIds = <String>{};
      final Map<String, String> matchIdByPartner = {};
      final Map<String, String?> eventIdByPartner = {};
      final Map<String, DateTime?> expiresByPartner = {};

      for (var match in matchesRes) {
        final status = match['status']?.toString().toLowerCase();
        if (status == 'rejected') continue;

        final u1 = match['user_id_1']?.toString() ?? '';
        final u2 = match['user_id_2']?.toString() ?? '';
        final otherId = u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1;
        if (otherId.isNotEmpty && otherId.toLowerCase() != currentId.toLowerCase()) {
          partnerUserIds.add(otherId);
          matchIdByPartner[otherId] = match['id']?.toString() ?? match['match_id']?.toString() ?? match['m_id']?.toString() ?? match['M_ID']?.toString() ?? '';
          eventIdByPartner[otherId] = match['event_id']?.toString();
          if (match['expires_at'] != null) {
            expiresByPartner[otherId] = DateTime.tryParse(match['expires_at'].toString());
          }
        }
      }

      for (var msg in directMessagesRes) {
        final sender = msg['sender_id']?.toString() ?? '';
        final receiver = msg['receiver_id']?.toString() ?? '';
        final otherId = sender.toLowerCase() == currentId.toLowerCase() ? receiver : sender;
        if (otherId.isNotEmpty && otherId.toLowerCase() != currentId.toLowerCase()) {
          partnerUserIds.add(otherId);
        }
      }

      for (var existingChat in _chats) {
        if (existingChat.participant.id.isNotEmpty) {
          partnerUserIds.add(existingChat.participant.id);
        }
      }

      Map<String, Map<String, dynamic>> profilesMap = {};
      Map<String, String> photosMap = {};
      Map<String, List<String>> socialLinksMap = {};

      final validUuidList = partnerUserIds.where((id) => _isValidUuid(id)).toList();

      if (validUuidList.isNotEmpty) {
        try {
          final profilesRes = await _supabase
              .from('users')
              .select('id, name, username, bio, city, gender, interests')
              .inFilter('id', validUuidList);

          for (var p in profilesRes) {
            profilesMap[p['id'].toString().toLowerCase()] = p;
          }
        } catch (_) {}

        try {
          final photosRes = await _supabase
              .from('user_photos')
              .select('user_id, storage_url')
              .inFilter('user_id', validUuidList)
              .eq('is_active', true)
              .order('sort_order', ascending: true);

          for (var photo in photosRes) {
            final uId = photo['user_id'].toString().toLowerCase();
            if (!photosMap.containsKey(uId)) {
              photosMap[uId] = photo['storage_url'].toString();
            }
          }
        } catch (_) {}

        try {
          final socialRes = await _supabase
              .from('user_social_links')
              .select('user_id, url')
              .inFilter('user_id', validUuidList);

          for (var link in socialRes) {
            final uId = link['user_id'].toString().toLowerCase();
            final url = link['url'].toString();
            socialLinksMap.putIfAbsent(uId, () => []).add(url);
          }
        } catch (_) {}
      }

      final Map<String, List<MessageModel>> messagesByPartner = {};

      for (var match in matchesRes) {
        final u1 = match['user_id_1']?.toString() ?? '';
        final u2 = match['user_id_2']?.toString() ?? '';
        final partnerId = (u1.toLowerCase() == currentId.toLowerCase() ? u2 : u1).toLowerCase();

        if (match['messages'] != null && match['messages'] is List) {
          for (var msg in match['messages']) {
            try {
              final msgModel = MessageModel(
                id: msg['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
                senderId: msg['sender_id']?.toString() ?? '',
                receiverId: msg['receiver_id']?.toString(),
                text: msg['content']?.toString() ?? msg['message']?.toString() ?? '',
                timestamp: msg['created_at'] != null
                    ? DateTime.tryParse(msg['created_at'].toString()) ?? DateTime.now()
                    : DateTime.now(),
                status: MessageStatus.delivered,
              );
              messagesByPartner.putIfAbsent(partnerId, () => []).add(msgModel);
            } catch (e) {
              debugPrint('MODEL PARSE HATASI: $e');
            }
          }
        }
      }

      for (var msg in directMessagesRes) {
        final sender = msg['sender_id']?.toString() ?? '';
        final receiver = msg['receiver_id']?.toString() ?? '';
        final partnerId = (sender.toLowerCase() == currentId.toLowerCase() ? receiver : sender).toLowerCase();

        try {
          final msgModel = MessageModel(
            id: msg['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
            senderId: sender,
            receiverId: receiver,
            text: msg['content']?.toString() ?? msg['message']?.toString() ?? '',
            timestamp: msg['created_at'] != null
                ? DateTime.tryParse(msg['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            status: MessageStatus.delivered,
          );

          messagesByPartner.putIfAbsent(partnerId, () => []).add(msgModel);
        } catch (e) {
          debugPrint('MODEL PARSE HATASI: $e');
        }
      }

      final Map<String, ChatModel> consolidatedChats = {};

      for (var partnerId in partnerUserIds) {
        final lowerPartnerId = partnerId.toLowerCase();
        final profile = profilesMap[lowerPartnerId];
        
        ChatModel? existingChat;
        for (var c in _chats) {
          if (c.participant.id.toLowerCase() == lowerPartnerId) {
            existingChat = c;
            break;
          }
        }

        final name = profile?['name'] ?? existingChat?.participant.name ?? 'Kullanıcı $partnerId';
        final username = profile?['username'] ?? existingChat?.participant.username;
        final bio = profile?['bio'] ?? existingChat?.participant.aboutMe;
        final city = profile?['city'] ?? existingChat?.participant.city;
        final gender = profile?['gender'] ?? existingChat?.participant.gender;
        final avatarUrl = photosMap[lowerPartnerId] ??
            existingChat?.participant.avatarUrl ??
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600';

        List<String> socialLinks = List<String>.from(socialLinksMap[lowerPartnerId] ?? existingChat?.participant.socialLinks ?? []);
        List<String> tags = [];
        if (profile?['interests'] != null && profile!['interests'] is List) {
          tags = List<String>.from(profile['interests'] as List);
        } else if (existingChat?.participant.tags != null) {
          tags = existingChat!.participant.tags;
        }

        final participant = UserModel(
          id: partnerId,
          name: name,
          username: username,
          avatarUrl: avatarUrl,
          aboutMe: bio,
          city: city,
          gender: gender,
          tags: tags,
          socialLinks: socialLinks,
        );

        final eventId = eventIdByPartner[partnerId];
        final event = eventId != null ? _eventService.getEventById(eventId) : existingChat?.relatedEvent;
        final matchId = matchIdByPartner[partnerId] ?? existingChat?.id ?? 'chat_$partnerId';

        final rawMessages = messagesByPartner[lowerPartnerId] ?? [];
        if (existingChat != null) {
          for (var localMsg in existingChat.messages) {
            rawMessages.add(localMsg);
          }
        }

        final dedupedMessages = <MessageModel>[];
        final seenMsgKeys = <String>{};

        for (var msg in rawMessages) {
          if (msg.text.trim().isEmpty) continue;
          final key = '${msg.id}_${msg.text}_${msg.senderId}';
          if (!seenMsgKeys.contains(key)) {
            seenMsgKeys.add(key);
            dedupedMessages.add(msg);
          }
        }

        dedupedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        consolidatedChats[lowerPartnerId] = ChatModel(
          id: matchId,
          participant: participant,
          isEventBased: event != null,
          relatedEvent: event,
          unreadCount: existingChat?.unreadCount ?? 0,
          messages: dedupedMessages,
          expiresAt: expiresByPartner[partnerId],
        );
      }

      final newChatsList = consolidatedChats.values.toList();
      newChatsList.sort((a, b) {
        final aTime = a.messages.isNotEmpty ? a.messages.last.timestamp : DateTime(2000);
        final bTime = b.messages.isNotEmpty ? b.messages.last.timestamp : DateTime(2000);
        return bTime.compareTo(aTime);
      });

      _chats = newChatsList;
      _isLoading = false;
      _saveChatsToLocalStorage();
      for (var chat in _chats) {
        _emitRoomUpdate(chat.participant.id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MessageService] ❌ Load Chats Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortChats() {
    _chats.sort((a, b) {
      final aTime = a.messages.isNotEmpty ? a.messages.last.timestamp : DateTime(2000);
      final bTime = b.messages.isNotEmpty ? b.messages.last.timestamp : DateTime(2000);
      return bTime.compareTo(aTime);
    });
  }

  /// 1. sendMessage İyileştirmesi: Web <-> Mobil Kesintisiz İletişim
  Future<void> sendMessage(String chatId, String text, {String? receiverUserId}) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    try {
      final currentId = currentUserId.isNotEmpty ? currentUserId : 'user_mobile';

      // 1. Önce chatId üzerinden ara
      int chatIndex = _chats.indexWhere((c) => c.id == chatId);

      // 2. Bulunamazsa receiverUserId üzerinden ara
      if (chatIndex < 0 && receiverUserId != null && receiverUserId.isNotEmpty) {
        final lowerReceiver = receiverUserId.toLowerCase();
        chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerReceiver);
      }

      // 3. Hala yoksa otomatik oluştur
      if (chatIndex < 0 && receiverUserId != null && receiverUserId.isNotEmpty) {
        final newChat = createOrGetChatForUser(UserModel(id: receiverUserId, name: 'Kullanıcı', avatarUrl: ''));
        chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == receiverUserId.toLowerCase());
      }

      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        final partnerId = receiverUserId?.isNotEmpty == true ? receiverUserId! : chat.participant.id;

        if (isBlocked(partnerId)) return;

        final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
        final now = DateTime.now();

        final newMsg = MessageModel(
          id: newMsgId,
          senderId: currentId,
          receiverId: partnerId,
          text: trimmedText,
          timestamp: now,
          status: MessageStatus.sent,
        );

        chat.messages.add(newMsg);
        _sortChats();
        _saveChatsToLocalStorage();
        _emitRoomUpdate(partnerId);
        notifyListeners();

        debugPrint('--> [TELEFON GÖNDERİYOR] Sender: $currentId | Receiver: $partnerId | Metin: $trimmedText');

        // WebSocket Broadcast yayını
        _broadcastChannel?.sendBroadcastMessage(
          event: 'new_message',
          payload: {
            'id': newMsgId,
            'sender_id': currentId,
            'receiver_id': partnerId,
            'content': trimmedText,
            'created_at': now.toUtc().toIso8601String(),
          },
        );

        // Veritabanına kalıcı yazma
        await _persistMessage(chat.id, partnerId, trimmedText, newMsgId, senderUserId: currentId);
      }
    } catch (e) {
      debugPrint('[MessageService] ❌ Send Message Error: $e');
    }
  }

  Future<void> _persistMessage(String chatId, String partnerId, String text, String clientMsgId, {String? senderUserId}) async {
    final effectiveSenderId = (senderUserId != null && senderUserId.isNotEmpty)
        ? senderUserId
        : (currentUserId.isNotEmpty ? currentUserId : 'user_mobile');

    if (partnerId.isEmpty) return;

    try {
      int? numericMatchId = int.tryParse(chatId);

      // Aktif sohbetteki match kaydını sorgula
      if (numericMatchId == null && partnerId.isNotEmpty) {
        try {
          final existingMatch = await _supabase
              .from('matches')
              .select('id')
              .or('and(user_id_1.eq.$effectiveSenderId,user_id_2.eq.$partnerId),and(user_id_1.eq.$partnerId,user_id_2.eq.$effectiveSenderId)')
              .maybeSingle();

          if (existingMatch != null) {
            numericMatchId = int.tryParse(existingMatch['id'].toString());
          }
        } catch (e) {
          debugPrint('[Match Query Error]: $e');
        }
      }

      // messages tablosuna doğrudan ve zorunlu insert
      final messagePayload = <String, dynamic>{
        'sender_id': effectiveSenderId,
        'receiver_id': partnerId,
        'content': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (numericMatchId != null) {
        messagePayload['match_id'] = numericMatchId;
      }

      await _supabase.from('messages').insert(messagePayload);
      debugPrint('--> [TELEFON BAŞARILI] Supabase messages tablosuna yazıldı: $messagePayload');
    } catch (e) {
      debugPrint('[MessageService] ❌ INSERT HATASI: ${e.toString()}');
    }
  }

  void markAsRead(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];
      chat.unreadCount = 0;
      for (var m in chat.messages) {
        m.status = MessageStatus.read;
      }
      _saveChatsToLocalStorage();
      _emitRoomUpdate(chat.participant.id);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (var controller in _roomStreamControllers.values) {
      controller.close();
    }
    _roomStreamControllers.clear();
    _unsubscribeFromRealtime();
    _authSubscription?.cancel();
    super.dispose();
  }
}
