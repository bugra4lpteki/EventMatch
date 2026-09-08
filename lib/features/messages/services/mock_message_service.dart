import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';
import '../models/message_model.dart';
import '../../events/models/user_model.dart';
import '../../events/services/mock_event_service.dart';

class MockMessageService extends ChangeNotifier with WidgetsBindingObserver {
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
  RealtimeChannel? _presenceChannel;
  final Set<String> _onlineUserIds = {};
  final Map<String, bool> _typingPartners = {};
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool isUserOnline(String userId) => _onlineUserIds.contains(userId.toLowerCase().trim());
  bool isPartnerTyping(String partnerId) => _typingPartners[partnerId.toLowerCase().trim()] == true;

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
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trackCurrentPresence();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _untrackCurrentPresence();
    }
  }

  void _trackCurrentPresence() {
    try {
      final currentId = currentUserId;
      if (currentId.isNotEmpty && _presenceChannel != null) {
        _presenceChannel!.track({
          'user_id': currentId,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Track presence error: $e');
    }
  }

  void _untrackCurrentPresence() {
    try {
      if (_presenceChannel != null) {
        _presenceChannel!.untrack();
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Untrack presence error: $e');
    }
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
          .onBroadcast(
            event: 'messages_read',
            callback: (payload) {
              _handleMessagesReadEvent(payload);
            },
          )
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              _handleTypingEvent(payload);
            },
          )
          .onBroadcast(
            event: 'message_reaction',
            callback: (payload) {
              _handleReactionEvent(payload);
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

      // 3. Online Presence Sync Channel (Gerçek Zamanlı Çevrimiçi Takibi)
      _presenceChannel = _supabase.channel('eventmatch_online_presence');
      _presenceChannel!
          .onPresenceSync((_) {
            _handlePresenceSync();
          })
          .subscribe((status, [error]) async {
            debugPrint('📡 [SUPABASE REALTIME] Presence kanalı durumu: $status');
            if (status == RealtimeSubscribeStatus.subscribed) {
              _trackCurrentPresence();
            }
          });

      // 4. Matches CDC Stream (Gerçek zamanlı karşılıklı eşleşme takibi)
      _matchesChannel = _supabase
          .channel('public_matches_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            callback: (payload) {
              _handlePostgresMatchEvent(payload);
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 [SUPABASE REALTIME] Matches CDC akışı durumu: $status');
          });

      debugPrint('[MessageService] 🚀 Multi-layer realtime kanalları aktif.');
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Realtime subscription error: $e');
    }
  }

  void _handlePostgresMatchEvent(PostgresChangePayload payload) {
    try {
      final currentId = currentUserId.toLowerCase().trim();
      if (currentId.isEmpty) return;

      final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (record.isEmpty) return;

      final u1 = (record['user_id_1']?.toString() ?? '').toLowerCase().trim();
      final u2 = (record['user_id_2']?.toString() ?? '').toLowerCase().trim();

      // Bu eşleşme etkinliği mevcut kullanıcıyı ilgilendiriyor mu?
      if (u1 != currentId && u2 != currentId) return;

      final status = payload.newRecord['status']?.toString().toLowerCase().trim();

      // Sadece iki taraf da eşleştiğinde ('matched') veya eşleşme bittiğinde/silindiğinde yenile
      if (status == 'matched' || payload.eventType == PostgresChangeEvent.delete || status == 'rejected') {
        debugPrint('[MessageService] 🔄 Karşılıklı eşleşme güncellendi ($status), sohbetler yenileniyor...');
        reloadChats();
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handlePostgresMatchEvent error: $e');
    }
  }

  void _handlePresenceSync() {
    try {
      if (_presenceChannel == null) return;
      final presenceState = _presenceChannel!.presenceState();
      final currentOnline = <String>{};

      for (var entry in presenceState) {
        for (var presence in entry.presences) {
          final pMap = presence.payload;
          final uid = pMap['user_id']?.toString().toLowerCase().trim();
          if (uid != null && uid.isNotEmpty) {
            currentOnline.add(uid);
          }
        }
      }

      _onlineUserIds.clear();
      _onlineUserIds.addAll(currentOnline);

      // Chat modellerinin isOnline durumlarını anında güncelle
      bool hasChange = false;
      for (var chat in _chats) {
        final shouldBeOnline = _onlineUserIds.contains(chat.participant.id.toLowerCase().trim());
        if (chat.isOnline != shouldBeOnline) {
          chat.isOnline = shouldBeOnline;
          hasChange = true;
        }
      }

      if (hasChange) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ Presence sync error: $e');
    }
  }

  void _unsubscribeFromRealtime() {
    try {
      _untrackCurrentPresence();
      _presenceChannel?.unsubscribe();
      _presenceChannel = null;
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

  void _handleMessagesReadEvent(Map<String, dynamic> payload) {
    try {
      final readerId = (payload['reader_id']?.toString() ?? '').toLowerCase().trim();
      final partnerId = (payload['partner_id']?.toString() ?? '').toLowerCase().trim();
      final currentId = currentUserId.toLowerCase().trim();

      // Bu bildirim bize mi gelmiş? (partner_id == currentId ve reader_id bizim mesajlaştığımız kişi)
      if (currentId.isEmpty || partnerId != currentId || readerId.isEmpty) return;

      final chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == readerId);
      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        bool changed = false;
        for (var m in chat.messages) {
          if (m.senderId.toLowerCase() == currentId && m.status != MessageStatus.read) {
            m.status = MessageStatus.read; // Okundu: Çift mavi tık!
            changed = true;
          }
        }
        if (changed) {
          _saveChatsToLocalStorage();
          _emitRoomUpdate(chat.participant.id);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handleMessagesReadEvent error: $e');
    }
  }

  void sendTypingStatus(String partnerId, bool isTyping) {
    try {
      final currentId = currentUserId;
      if (currentId.isEmpty || partnerId.isEmpty) return;
      _broadcastChannel?.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'sender_id': currentId,
          'receiver_id': partnerId,
          'is_typing': isTyping,
        },
      );
    } catch (_) {}
  }

  void _handleTypingEvent(Map<String, dynamic> payload) {
    try {
      final senderId = (payload['sender_id']?.toString() ?? '').toLowerCase().trim();
      final receiverId = (payload['receiver_id']?.toString() ?? '').toLowerCase().trim();
      final currentId = currentUserId.toLowerCase().trim();
      final isTyping = payload['is_typing'] == true;

      if (currentId.isEmpty || receiverId != currentId || senderId.isEmpty) return;

      if (_typingPartners[senderId] != isTyping) {
        _typingPartners[senderId] = isTyping;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handleTypingEvent error: $e');
    }
  }

  void _handleReactionEvent(Map<String, dynamic> payload) {
    try {
      final msgId = payload['message_id']?.toString();
      final reactorId = (payload['sender_id']?.toString() ?? '').toLowerCase().trim();
      final receiverId = (payload['receiver_id']?.toString() ?? '').toLowerCase().trim();
      final currentId = currentUserId.toLowerCase().trim();
      final emoji = payload['emoji']?.toString() ?? '';

      if (msgId == null || msgId.isEmpty || currentId.isEmpty) return;
      if (receiverId != currentId && reactorId != currentId) return;

      final partnerId = reactorId == currentId ? receiverId : reactorId;
      final chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == partnerId);
      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        final mIndex = chat.messages.indexWhere((m) => m.id == msgId);
        if (mIndex >= 0) {
          final m = chat.messages[mIndex];
          final updatedReactions = Map<String, String>.from(m.reactions);
          if (emoji.isEmpty) {
            updatedReactions.remove(reactorId);
          } else {
            updatedReactions[reactorId] = emoji;
          }
          chat.messages[mIndex] = m.copyWith(reactions: updatedReactions);
          _saveChatsToLocalStorage();
          _emitRoomUpdate(chat.participant.id);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handleReactionEvent error: $e');
    }
  }

  Future<void> toggleReaction(String chatId, String messageId, String partnerId, String emoji) async {
    try {
      final currentId = currentUserId;
      final lowerCurrent = currentId.toLowerCase().trim();
      final lowerPartner = partnerId.toLowerCase().trim();
      if (currentId.isEmpty || partnerId.isEmpty) return;

      final chatIndex = _chats.indexWhere((c) =>
          c.id == chatId || c.participant.id.toLowerCase() == lowerPartner);

      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        final mIndex = chat.messages.indexWhere((m) => m.id == messageId);
        if (mIndex >= 0) {
          final m = chat.messages[mIndex];
          final updatedReactions = Map<String, String>.from(m.reactions);
          final currentReaction = updatedReactions[lowerCurrent];
          String targetEmoji = emoji;
          if (currentReaction == emoji) {
            updatedReactions.remove(lowerCurrent);
            targetEmoji = '';
          } else {
            updatedReactions[lowerCurrent] = emoji;
          }

          chat.messages[mIndex] = m.copyWith(reactions: updatedReactions);
          _saveChatsToLocalStorage();
          _emitRoomUpdate(chat.participant.id);
          notifyListeners();

          _broadcastChannel?.sendBroadcastMessage(
            event: 'message_reaction',
            payload: {
              'message_id': messageId,
              'sender_id': currentId,
              'receiver_id': partnerId,
              'emoji': targetEmoji,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[MessageService] ⚠️ toggleReaction error: $e');
    }
  }

  void _handleBroadcastMessage(Map<String, dynamic> payload) {
    try {
      final senderId = (payload['sender_id']?.toString() ?? payload['user_id']?.toString() ?? '').toLowerCase().trim();
      final receiverId = (payload['receiver_id']?.toString() ?? '').toLowerCase().trim();
      final content = payload['content']?.toString() ?? '';
      final msgId = payload['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final createdAtStr = payload['created_at']?.toString();
      final timestamp = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

      if (content.trim().isEmpty) return;

      final currentId = currentUserId.toLowerCase().trim();
      if (currentId.isEmpty) return;

      // KESİN GÜVENLİK FİLTRESİ:
      // SADECE mevcut kullanıcı bu mesajın göndericisi VEYA alıcısı ise işle!
      final isSender = senderId == currentId;
      final isReceiver = receiverId == currentId;

      if (!isSender && !isReceiver) {
        // Bu mesaj tamamen başka iki kullanıcı arasındaki özel bir mesajlaşmadır!
        // Başka hesaplara sızmasını kesinlikle engelliyoruz.
        return;
      }

      final partnerId = isSender ? receiverId : senderId;
      if (partnerId.isEmpty || partnerId == currentId) return;
      if (isBlocked(partnerId) || isBlocked(senderId)) return;

      _injectMessageIntoChat(
        partnerId: partnerId,
        msgId: msgId,
        senderId: payload['sender_id']?.toString() ?? senderId,
        receiverId: payload['receiver_id']?.toString() ?? receiverId,
        content: content,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('[MessageService] ⚠️ handleBroadcastMessage error: $e');
    }
  }

  void _handlePostgresMessageEvent(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record.isEmpty) return;

      final senderId = (record['sender_id']?.toString() ?? '').toLowerCase().trim();
      final receiverId = (record['receiver_id']?.toString() ?? '').toLowerCase().trim();
      final content = record['content']?.toString() ?? record['message']?.toString() ?? '';
      final msgId = record['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final createdAtStr = record['created_at']?.toString();
      final timestamp = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

      if (content.trim().isEmpty) return;

      final currentId = currentUserId.toLowerCase().trim();
      if (currentId.isEmpty) return;

      // KESİN GÜVENLİK FİLTRESİ:
      // SADECE mevcut kullanıcı bu mesajın göndericisi VEYA alıcısı ise işle!
      final isSender = senderId == currentId;
      final isReceiver = receiverId == currentId;

      if (!isSender && !isReceiver) {
        // Bu mesaj başka hesaplara ait, kesinlikle bu hesaba eklenemez!
        return;
      }

      final partnerId = isSender ? receiverId : senderId;
      if (partnerId.isEmpty || partnerId == currentId) return;
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

    final lowerCurrent = currentUserId.toLowerCase().trim();
    final lowerPartnerId = partnerId.toLowerCase().trim();
    final lowerSender = senderId.toLowerCase().trim();
    final lowerReceiver = receiverId.toLowerCase().trim();

    // Mesajın gerçekten bu iki taraf arasında olduğunu doğrula
    final isValidPair = (lowerSender == lowerCurrent && lowerReceiver == lowerPartnerId) ||
                        (lowerSender == lowerPartnerId && lowerReceiver == lowerCurrent);

    if (!isValidPair) {
      debugPrint('[MessageService] 🛑 injectMessage engellendi: Mesaj bu sohbete ait değil ($lowerSender -> $lowerReceiver, current: $lowerCurrent, partner: $lowerPartnerId)');
      return;
    }

    final chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartnerId);

    if (chatIndex < 0) {
      // Sohbet henüz yerel listede yoksa, sohbetleri yenile ve ardından mesajı ve bildirimi üret
      reloadChats().then((_) {
        final newIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartnerId);
        if (newIndex >= 0) {
          _injectMessageIntoChat(
            partnerId: partnerId,
            msgId: msgId,
            senderId: senderId,
            receiverId: receiverId,
            content: content,
            timestamp: timestamp,
          );
        } else if (lowerSender != lowerCurrent) {
          // Eşleşme sorgusu gecikse bile kullanıcıya bildirimi anında ulaştır
          _supabase.from('users').select('name').eq('id', partnerId).maybeSingle().then((uData) {
            final senderName = uData?['name']?.toString() ?? 'Yeni Eşleşme';
            NotificationService().showMessageNotification(
              chatId: partnerId,
              senderName: senderName,
              message: content,
              unreadCount: 1,
              messageId: msgId,
            );
          }).catchError((_) {
            NotificationService().showMessageNotification(
              chatId: partnerId,
              senderName: 'Yeni Eşleşme',
              message: content,
              unreadCount: 1,
              messageId: msgId,
            );
          });
        }
      });
      return;
    }

    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];

      // 1. KESİN ID KONTROLÜ: Aynı mesaj ID'si varsa kesinlikle mükerrerdir, yok say
      if (chat.messages.any((m) => m.id == msgId)) {
        return;
      }

      // 2. OPTIMISTIC MESAJ UZLAŞTIRMASI:
      // Gönderici istemci tarafında geçici 'msg_' ID'siyle eklemişse,
      // bu mesajı tekrar eklemek YERİNE var olan geçici mesajın ID'sini ve durumunu güncelle!
      final optIndex = chat.messages.indexWhere((m) =>
          m.id.startsWith('msg_') &&
          m.senderId.toLowerCase().trim() == lowerSender &&
          (m.text.trim() == content.trim() ||
           content.contains(m.text.trim()) ||
           (m.isAudio && content.startsWith('[audio:'))) &&
          m.timestamp.difference(timestamp).abs().inSeconds < 120);

      if (optIndex >= 0) {
        final old = chat.messages[optIndex];
        chat.messages[optIndex] = old.copyWith(
          id: msgId,
          timestamp: timestamp,
          status: MessageStatus.sent, // DB onayladı: Tek gri tık
        );
        _deduplicateMessagesList(chat.messages);
        _saveChatsToLocalStorage();
        _emitRoomUpdate(partnerId);
        notifyListeners();
        return;
      }

      // 3. YAKIN ZAMANLI MÜKERRER KONTROLÜ:
      final duplicateIndex = chat.messages.indexWhere((m) =>
          m.senderId.toLowerCase().trim() == lowerSender &&
          (m.text.trim() == content.trim() || (m.isAudio && content.startsWith('[audio:'))) &&
          m.timestamp.difference(timestamp).abs().inSeconds < 15);

      if (duplicateIndex >= 0) {
        debugPrint('[MessageService] ⏭️ Yakın zamanlı mükerrer mesaj filtrelendi: $content');
        return;
      }

      final parsed = MessageModel.parseEncodedContent(content);
      final newMsg = MessageModel(
        id: msgId,
        senderId: senderId,
        receiverId: receiverId,
        text: parsed.cleanText.isNotEmpty ? parsed.cleanText : content,
        timestamp: timestamp,
        status: MessageStatus.delivered,
        replyToSenderName: parsed.replySender,
        replyToText: parsed.replyText,
        mediaUrl: parsed.mediaUrl,
        audioDurationSeconds: parsed.audioDuration,
        messageType: parsed.messageType,
      );
      chat.messages.add(newMsg);
      _deduplicateMessagesList(chat.messages);

      if (lowerSender != lowerCurrent) {
        chat.unreadCount += 1;
        if (!chat.isMuted) {
          NotificationService().showMessageNotification(
            chatId: partnerId,
            senderName: chat.participant.name,
            message: parsed.cleanText.isNotEmpty ? parsed.cleanText : content,
            unreadCount: chat.unreadCount,
            messageId: msgId,
          );
        }
      }
      _sortChats();
      _saveChatsToLocalStorage();
      _emitRoomUpdate(partnerId);
      notifyListeners();
    }
  }

  /// Tüm sohbet mesajları listesini mükerrer kayıtlardan temizleyen kesin filtreleme motoru
  static void _deduplicateMessagesList(List<MessageModel> list) {
    if (list.length <= 1) return;

    final seenIds = <String>{};
    final toRemove = <MessageModel>[];

    // 1. Aynı ID'ye sahip mükerrer kayıtları temizle
    for (int i = 0; i < list.length; i++) {
      final m = list[i];
      if (seenIds.contains(m.id)) {
        toRemove.add(m);
      } else {
        seenIds.add(m.id);
      }
    }
    for (var m in toRemove) {
      list.remove(m);
    }
    toRemove.clear();

    // 2. Aynı gönderici, aynı metin ve 15 saniye içinde gönderilmiş geçici (optimistic) ile gerçek DB kayıtlarını uzlaştır
    for (int i = 0; i < list.length; i++) {
      for (int j = i + 1; j < list.length; j++) {
        final m1 = list[i];
        final m2 = list[j];
        if (m1.senderId.toLowerCase().trim() == m2.senderId.toLowerCase().trim() &&
            m1.text.trim() == m2.text.trim() &&
            m1.timestamp.difference(m2.timestamp).abs().inSeconds < 15) {
          // Biri geçici 'msg_' ile başlıyorsa, diğeri kalıcı DB ID'li ise geçiciyi kaldır
          if (m1.id.startsWith('msg_') && !m2.id.startsWith('msg_')) {
            toRemove.add(m1);
          } else {
            toRemove.add(m2);
          }
        }
      }
    }
    for (var m in toRemove) {
      list.remove(m);
    }

    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
    _deletedChatIds.add(chatId);
    _deletedChatIds.add(lowerPartnerId);
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
      isOnline: isUserOnline(user.id),
    );

    final initialClientMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    if (initialMessage != null && initialMessage.trim().isNotEmpty) {
      final firstMsg = MessageModel(
        id: initialClientMsgId,
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
      _persistMessage(newChat.id, user.id, initialMessage.trim(), initialClientMsgId);
    }

    return newChat;
  }

  // --- SMART BACKGROUND SYNC (CANLI ANLIK SENKRONİZASYON) ---
  Future<void> syncChatMessagesForPartner(String partnerId) async {
    final currentId = currentUserId.trim();
    final partner = partnerId.trim();
    if (partner.isEmpty || currentId.isEmpty) return;

    try {
      final lowerCurrent = currentId.toLowerCase();
      final lowerPartner = partner.toLowerCase();

      if (lowerCurrent == lowerPartner) return;

      // SADECE ve SADECE bu iki kullanıcı arasındaki karşılıklı mesajları sorgula
      final res = await _supabase
          .from('messages')
          .select('*')
          .or('and(sender_id.eq.$currentId,receiver_id.eq.$partner),and(sender_id.eq.$partner,receiver_id.eq.$currentId)')
          .order('created_at', ascending: true);

      int chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerPartner);
      if (chatIndex < 0) {
        final newChat = createOrGetChatForUser(UserModel(id: partner, name: 'Kullanıcı', avatarUrl: ''));
        chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == lowerPartner);
      }

      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        bool hasNew = false;

        for (var row in res) {
          try {
            final s = (row['sender_id']?.toString() ?? '').toLowerCase().trim();
            final r = (row['receiver_id']?.toString() ?? '').toLowerCase().trim();

            final isForThisChat = (s == lowerCurrent && r == lowerPartner) ||
                                  (s == lowerPartner && r == lowerCurrent);

            if (!isForThisChat) continue;

            final mId = row['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
            final text = row['content']?.toString() ?? row['message']?.toString() ?? '';
            final sender = row['sender_id']?.toString() ?? '';
            final receiver = row['receiver_id']?.toString() ?? '';
            final ts = row['created_at'] != null ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now() : DateTime.now();

            if (text.trim().isEmpty) continue;

            final isRead = row['is_read'] == true || row['status'] == 'read';
            final isFromMe = sender.toLowerCase().trim() == lowerCurrent;
            final calculatedStatus = isRead
                ? MessageStatus.read
                : (isFromMe ? MessageStatus.sent : MessageStatus.delivered);

            final parsed = MessageModel.parseEncodedContent(text);
            final cleanMsgText = parsed.cleanText.isNotEmpty ? parsed.cleanText : text;

            // 1. Zaten aynı kesin veritabanı ID'si varsa, durumunu (okundu/iletildi) güncelle
            final exactIdIndex = chat.messages.indexWhere((m) => m.id == mId);
            if (exactIdIndex >= 0) {
              if (chat.messages[exactIdIndex].status != calculatedStatus) {
                chat.messages[exactIdIndex].status = calculatedStatus;
                hasNew = true;
              }
              continue;
            }

            // 2. Geçici optimistic ID'li ('msg_...') bir mesaj varsa onu bu gerçek ID'ye güncelle
            final optIndex = chat.messages.indexWhere((m) =>
                m.id.startsWith('msg_') &&
                m.senderId.toLowerCase().trim() == sender.toLowerCase().trim() &&
                (m.text.trim() == cleanMsgText.trim() || text.contains(m.text.trim()) || (m.isAudio && text.startsWith('[audio:'))) &&
                m.timestamp.difference(ts).abs().inSeconds < 120);

            if (optIndex >= 0) {
              final old = chat.messages[optIndex];
              chat.messages[optIndex] = old.copyWith(
                id: mId,
                timestamp: ts,
                status: calculatedStatus,
              );
              hasNew = true;
              continue;
            }

            // 3. 15 saniye içinde aynı kullanıcıdan aynı metin varsa mükerrerdir, yok say
            final recentDupIndex = chat.messages.indexWhere((m) =>
                m.senderId.toLowerCase().trim() == sender.toLowerCase().trim() &&
                (m.text.trim() == cleanMsgText.trim() || (m.isAudio && text.startsWith('[audio:'))) &&
                m.timestamp.difference(ts).abs().inSeconds < 15);

            if (recentDupIndex >= 0) {
              continue;
            }

            // 4. Yeni bir mesaj, listeye ekle
            chat.messages.add(MessageModel(
              id: mId,
              senderId: sender,
              receiverId: receiver,
              text: cleanMsgText,
              timestamp: ts,
              status: calculatedStatus,
              replyToSenderName: parsed.replySender,
              replyToText: parsed.replyText,
              mediaUrl: parsed.mediaUrl,
              audioDurationSeconds: parsed.audioDuration,
              messageType: parsed.messageType,
            ));
            hasNew = true;
          } catch (e) {
            debugPrint('MODEL PARSE HATASI: $e');
          }
        }

        _deduplicateMessagesList(chat.messages);
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

      bool querySucceeded = false;
      List<dynamic> matchesRes = [];
      try {
        matchesRes = await _supabase
            .from('matches')
            .select('*, messages(*)')
            .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId')
            .eq('status', 'matched');
        querySucceeded = true;
      } catch (e) {
        try {
          matchesRes = await _supabase
              .from('matches')
              .select('*')
              .or('user_id_1.eq.$currentId,user_id_2.eq.$currentId')
              .eq('status', 'matched');
          querySucceeded = true;
        } catch (_) {}
      }

      if (!querySucceeded) {
        // Ağ bağlantı sorunu varsa yerel önbelleği koru
        _isLoading = false;
        notifyListeners();
        return;
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
        final status = match['status']?.toString().toLowerCase().trim();
        // KESİN KURAL: SADECE iki taraf da karşılıklı eşleştiyse (status == 'matched') sohbet oluşturulur!
        // 'liked' (tek taraflı beğeni / eşleşme isteği), 'pending' veya 'rejected' olanlar sohbet kutusuna DÜŞEMEZ!
        if (status != 'matched') continue;

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

      final Map<String, Map<String, dynamic>> profilesMap = {};
      final Map<String, String> photosMap = {};
      final Map<String, List<String>> socialLinksMap = {};

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
        final u1 = (match['user_id_1']?.toString() ?? '').trim();
        final u2 = (match['user_id_2']?.toString() ?? '').trim();
        final lowerCurrent = currentId.toLowerCase();
        final partnerId = (u1.toLowerCase() == lowerCurrent ? u2 : u1);
        final lowerPartnerId = partnerId.toLowerCase();

        if (partnerId.isEmpty || lowerPartnerId == lowerCurrent) continue;

        if (match['messages'] != null && match['messages'] is List) {
          for (var msg in match['messages']) {
            try {
              final s = (msg['sender_id']?.toString() ?? '').toLowerCase().trim();
              final r = (msg['receiver_id']?.toString() ?? '').toLowerCase().trim();

              final isValid = (s == lowerCurrent && r == lowerPartnerId) ||
                              (s == lowerPartnerId && r == lowerCurrent) ||
                              (r.isEmpty && (s == lowerCurrent || s == lowerPartnerId));
              if (!isValid) continue;

              final isRead = msg['is_read'] == true || msg['status'] == 'read';
              final isFromMe = s == lowerCurrent;
              final calculatedStatus = isRead
                  ? MessageStatus.read
                  : (isFromMe ? MessageStatus.sent : MessageStatus.delivered);

              final rawText = msg['content']?.toString() ?? msg['message']?.toString() ?? msg['text']?.toString() ?? '';
              final parsed = MessageModel.parseEncodedContent(rawText);

              final msgModel = MessageModel(
                id: msg['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
                senderId: msg['sender_id']?.toString() ?? '',
                receiverId: msg['receiver_id']?.toString(),
                text: parsed.cleanText.isNotEmpty ? parsed.cleanText : rawText,
                timestamp: msg['created_at'] != null
                    ? DateTime.tryParse(msg['created_at'].toString()) ?? DateTime.now()
                    : DateTime.now(),
                status: calculatedStatus,
                replyToSenderName: parsed.replySender,
                replyToText: parsed.replyText,
                mediaUrl: parsed.mediaUrl,
                audioDurationSeconds: parsed.audioDuration,
                messageType: parsed.messageType,
              );
              messagesByPartner.putIfAbsent(lowerPartnerId, () => []).add(msgModel);
            } catch (e) {
              debugPrint('MODEL PARSE HATASI: $e');
            }
          }
        }
      }

      for (var msg in directMessagesRes) {
        final sender = (msg['sender_id']?.toString() ?? '').trim();
        final receiver = (msg['receiver_id']?.toString() ?? '').trim();
        final lowerCurrent = currentId.toLowerCase();
        final lowerSender = sender.toLowerCase();
        final lowerReceiver = receiver.toLowerCase();

        String partnerId = '';
        if (lowerSender == lowerCurrent && lowerReceiver.isNotEmpty && lowerReceiver != lowerCurrent) {
          partnerId = receiver;
        } else if (lowerReceiver == lowerCurrent && lowerSender.isNotEmpty && lowerSender != lowerCurrent) {
          partnerId = sender;
        } else {
          continue;
        }

        // SADECE ve SADECE karşılıklı onaylanmış eşleşmesi (status == 'matched') bulunan partnerlerin mesajları eklenir
        final lowerPartner = partnerId.toLowerCase();
        if (!partnerUserIds.any((id) => id.toLowerCase() == lowerPartner)) {
          continue;
        }

        try {
          final isRead = msg['is_read'] == true || msg['status'] == 'read';
          final isFromMe = lowerSender == lowerCurrent;
          final calculatedStatus = isRead
              ? MessageStatus.read
              : (isFromMe ? MessageStatus.sent : MessageStatus.delivered);

          final rawText = msg['content']?.toString() ?? msg['message']?.toString() ?? msg['text']?.toString() ?? '';
          final parsed = MessageModel.parseEncodedContent(rawText);

          final msgModel = MessageModel(
            id: msg['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
            senderId: sender,
            receiverId: receiver,
            text: parsed.cleanText.isNotEmpty ? parsed.cleanText : rawText,
            timestamp: msg['created_at'] != null
                ? DateTime.tryParse(msg['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            status: calculatedStatus,
            replyToSenderName: parsed.replySender,
            replyToText: parsed.replyText,
            mediaUrl: parsed.mediaUrl,
            audioDurationSeconds: parsed.audioDuration,
            messageType: parsed.messageType,
          );

          messagesByPartner.putIfAbsent(partnerId.toLowerCase(), () => []).add(msgModel);
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

        final List<String> socialLinks = List<String>.from(socialLinksMap[lowerPartnerId] ?? existingChat?.participant.socialLinks ?? []);
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

        final List<MessageModel> rawMessages = List<MessageModel>.from(messagesByPartner[lowerPartnerId] ?? []);
        if (existingChat != null) {
          final lowerCurrent = currentId.toLowerCase();
          for (var localMsg in existingChat.messages) {
            final s = localMsg.senderId.toLowerCase().trim();
            final r = (localMsg.receiverId ?? '').toLowerCase().trim();
            final isLocalValid = (s == lowerCurrent && (r == lowerPartnerId || r.isEmpty)) ||
                                 (s == lowerPartnerId && (r == lowerCurrent || r.isEmpty));
            if (!isLocalValid) continue;

            // Eğer bu yerel mesaj sunucudan gelen mesajlar arasında zaten varsa kesinlikle tekrar ekleme
            final alreadyInServer = rawMessages.any((m) =>
                m.id == localMsg.id ||
                (m.senderId.toLowerCase().trim() == s &&
                 m.text.trim() == localMsg.text.trim() &&
                 m.timestamp.difference(localMsg.timestamp).abs().inSeconds < 120));

            if (!alreadyInServer) {
              rawMessages.add(localMsg);
            }
          }
        }

        final dedupedMessages = List<MessageModel>.from(rawMessages);
        _deduplicateMessagesList(dedupedMessages);

        consolidatedChats[lowerPartnerId] = ChatModel(
          id: matchId,
          participant: participant,
          isEventBased: event != null,
          relatedEvent: event,
          unreadCount: existingChat?.unreadCount ?? 0,
          messages: dedupedMessages,
          expiresAt: expiresByPartner[partnerId],
          isOnline: isUserOnline(partnerId),
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

  /// 1. sendMessage: Metin ve Alıntılı Yanıt (Swipe-to-Reply) Gönderme
  Future<void> sendMessage(
    String chatId,
    String text, {
    String? receiverUserId,
    MessageModel? replyToMessage,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    try {
      final currentId = currentUserId.isNotEmpty ? currentUserId : 'user_mobile';

      int chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex < 0 && receiverUserId != null && receiverUserId.isNotEmpty) {
        final lowerReceiver = receiverUserId.toLowerCase();
        chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == lowerReceiver);
      }
      if (chatIndex < 0 && receiverUserId != null && receiverUserId.isNotEmpty) {
        final newChat = createOrGetChatForUser(UserModel(id: receiverUserId, name: 'Kullanıcı', avatarUrl: ''));
        chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == receiverUserId.toLowerCase());
      }

      if (chatIndex >= 0) {
        final chat = _chats[chatIndex];
        final partnerId = receiverUserId?.isNotEmpty == true ? receiverUserId! : chat.participant.id;

        if (partnerId.isEmpty || partnerId.toLowerCase() == currentId.toLowerCase()) return;
        if (isBlocked(partnerId)) return;

        final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
        final now = DateTime.now();

        String? replySender;
        String? replyText;
        String encodedContent = trimmedText;

        if (replyToMessage != null) {
          replySender = replyToMessage.senderId.toLowerCase().trim() == currentId.toLowerCase().trim()
              ? 'Sen'
              : chat.participant.name;
          replyText = replyToMessage.isAudio ? '🎤 Sesli Mesaj' : replyToMessage.text;
          encodedContent = '[reply:$replySender:$replyText]\n$trimmedText';
        }

        final newMsg = MessageModel(
          id: newMsgId,
          senderId: currentId,
          receiverId: partnerId,
          text: trimmedText,
          timestamp: now,
          status: MessageStatus.sending, // Başlangıçta saati göster: Gönderiliyor
          replyToMessageId: replyToMessage?.id,
          replyToText: replyText,
          replyToSenderName: replySender,
        );

        chat.messages.add(newMsg);
        _sortChats();
        _saveChatsToLocalStorage();
        _emitRoomUpdate(partnerId);
        notifyListeners();

        // WebSocket Broadcast yayını (Canlı iletim)
        _broadcastChannel?.sendBroadcastMessage(
          event: 'new_message',
          payload: {
            'id': newMsgId,
            'sender_id': currentId,
            'receiver_id': partnerId,
            'content': encodedContent,
            'created_at': now.toUtc().toIso8601String(),
            'reply_to_id': replyToMessage?.id,
            'reply_to_text': replyText,
            'reply_to_sender_name': replySender,
          },
        );

        sendTypingStatus(partnerId, false);

        // Veritabanına kalıcı yazma
        await _persistMessage(chat.id, partnerId, encodedContent, newMsgId, senderUserId: currentId);
      }
    } catch (e) {
      debugPrint('[MessageService] ❌ Send Message Error: $e');
    }
  }

  /// 2. Sesli Mesaj Gönderme (Voice Note)
  Future<void> sendVoiceNote(
    String chatId,
    String partnerId,
    String localAudioPath,
    int durationSeconds, {
    MessageModel? replyToMessage,
  }) async {
    try {
      final currentId = currentUserId.isNotEmpty ? currentUserId : 'user_mobile';
      if (partnerId.isEmpty || partnerId.toLowerCase() == currentId.toLowerCase()) return;
      if (isBlocked(partnerId)) return;

      int chatIndex = _chats.indexWhere((c) => c.id == chatId || c.participant.id.toLowerCase() == partnerId.toLowerCase());
      if (chatIndex < 0) {
        final newChat = createOrGetChatForUser(UserModel(id: partnerId, name: 'Kullanıcı', avatarUrl: ''));
        chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == partnerId.toLowerCase());
      }
      if (chatIndex < 0) return;

      final chat = _chats[chatIndex];
      final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final file = File(localAudioPath);
      String audioUrl = localAudioPath;

      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          final storagePath = 'chat_audio/${DateTime.now().millisecondsSinceEpoch}_${currentId.hashCode.abs()}.m4a';
          await _supabase.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: true),
          );
          audioUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);
        } catch (e) {
          debugPrint('[MessageService] ⚠️ Audio upload fallback: $e');
        }
      }

      String? replySender;
      String? replyText;
      String encodedContent = '[audio:$audioUrl:$durationSeconds]';

      if (replyToMessage != null) {
        replySender = replyToMessage.senderId.toLowerCase().trim() == currentId.toLowerCase().trim()
            ? 'Sen'
            : chat.participant.name;
        replyText = replyToMessage.isAudio ? '🎤 Sesli Mesaj' : replyToMessage.text;
        encodedContent = '[reply:$replySender:$replyText]\n$encodedContent';
      }

      final newMsg = MessageModel(
        id: newMsgId,
        senderId: currentId,
        receiverId: partnerId,
        text: '🎤 Sesli Mesaj',
        timestamp: now,
        status: MessageStatus.sending,
        mediaUrl: audioUrl,
        audioDurationSeconds: durationSeconds,
        messageType: 'audio',
        replyToMessageId: replyToMessage?.id,
        replyToText: replyText,
        replyToSenderName: replySender,
      );

      chat.messages.add(newMsg);
      _sortChats();
      _saveChatsToLocalStorage();
      _emitRoomUpdate(partnerId);
      notifyListeners();

      _broadcastChannel?.sendBroadcastMessage(
        event: 'new_message',
        payload: {
          'id': newMsgId,
          'sender_id': currentId,
          'receiver_id': partnerId,
          'content': encodedContent,
          'created_at': now.toUtc().toIso8601String(),
          'media_url': audioUrl,
          'audio_duration': durationSeconds,
          'message_type': 'audio',
          'reply_to_id': replyToMessage?.id,
          'reply_to_text': replyText,
          'reply_to_sender_name': replySender,
        },
      );

      sendTypingStatus(partnerId, false);

      await _persistMessage(chat.id, partnerId, encodedContent, newMsgId, senderUserId: currentId);
    } catch (e) {
      debugPrint('[MessageService] ❌ Send Voice Note Error: $e');
    }
  }

  /// 3. Fotoğraf Gönderme (Photo / Image Message)
  Future<void> sendImageMessage(
    String chatId,
    String partnerId,
    String localImagePath, {
    String? caption,
    MessageModel? replyToMessage,
  }) async {
    try {
      final currentId = currentUserId.isNotEmpty ? currentUserId : 'user_mobile';
      if (partnerId.isEmpty || partnerId.toLowerCase() == currentId.toLowerCase()) return;
      if (isBlocked(partnerId)) return;

      int chatIndex = _chats.indexWhere((c) => c.id == chatId || c.participant.id.toLowerCase() == partnerId.toLowerCase());
      if (chatIndex < 0) {
        final newChat = createOrGetChatForUser(UserModel(id: partnerId, name: 'Kullanıcı', avatarUrl: ''));
        chatIndex = _chats.indexWhere((c) => c.id == newChat.id || c.participant.id.toLowerCase() == partnerId.toLowerCase());
      }
      if (chatIndex < 0) return;

      final chat = _chats[chatIndex];
      final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final file = File(localImagePath);
      String imageUrl = localImagePath;

      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          final isPng = localImagePath.toLowerCase().endsWith('.png');
          final ext = isPng ? 'png' : 'jpg';
          final storagePath = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${currentId.hashCode.abs()}.$ext';
          await _supabase.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: isPng ? 'image/png' : 'image/jpeg', upsert: true),
          );
          imageUrl = _supabase.storage.from('avatars').getPublicUrl(storagePath);
        } catch (e) {
          debugPrint('[MessageService] ⚠️ Image upload fallback: $e');
        }
      }

      final trimmedCaption = caption?.trim() ?? '';
      String? replySender;
      String? replyText;
      String encodedContent = '[image:$imageUrl]${trimmedCaption.isNotEmpty ? '\n$trimmedCaption' : ''}';

      if (replyToMessage != null) {
        replySender = replyToMessage.senderId.toLowerCase().trim() == currentId.toLowerCase().trim()
            ? 'Sen'
            : chat.participant.name;
        replyText = replyToMessage.isAudio
            ? '🎤 Sesli Mesaj'
            : (replyToMessage.isImage ? '📷 Fotoğraf' : replyToMessage.text);
        encodedContent = '[reply:$replySender:$replyText]\n$encodedContent';
      }

      final newMsg = MessageModel(
        id: newMsgId,
        senderId: currentId,
        receiverId: partnerId,
        text: trimmedCaption.isNotEmpty ? trimmedCaption : '📷 Fotoğraf',
        timestamp: now,
        status: MessageStatus.sending,
        mediaUrl: imageUrl,
        messageType: 'image',
        replyToMessageId: replyToMessage?.id,
        replyToText: replyText,
        replyToSenderName: replySender,
      );

      chat.messages.add(newMsg);
      _sortChats();
      _saveChatsToLocalStorage();
      _emitRoomUpdate(partnerId);
      notifyListeners();

      _broadcastChannel?.sendBroadcastMessage(
        event: 'new_message',
        payload: {
          'id': newMsgId,
          'sender_id': currentId,
          'receiver_id': partnerId,
          'content': encodedContent,
          'created_at': now.toUtc().toIso8601String(),
          'media_url': imageUrl,
          'message_type': 'image',
          'reply_to_id': replyToMessage?.id,
          'reply_to_text': replyText,
          'reply_to_sender_name': replySender,
        },
      );

      sendTypingStatus(partnerId, false);

      await _persistMessage(chat.id, partnerId, encodedContent, newMsgId, senderUserId: currentId);
    } catch (e) {
      debugPrint('[MessageService] ❌ Send Image Error: $e');
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

      final insertedRow = await _supabase.from('messages').insert(messagePayload).select('id, created_at').maybeSingle();
      debugPrint('--> [TELEFON BAŞARILI] Supabase messages tablosuna yazıldı: $messagePayload');

      if (insertedRow != null) {
        final realId = insertedRow['id']?.toString();
        final createdAtStr = insertedRow['created_at']?.toString();
        final realTs = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

        if (realId != null && realId.isNotEmpty) {
          final chatIndex = _chats.indexWhere((c) => c.participant.id.toLowerCase() == partnerId.toLowerCase());
          if (chatIndex >= 0) {
            final chat = _chats[chatIndex];
            final optIdx = chat.messages.indexWhere((m) => m.id == clientMsgId);
            if (optIdx >= 0) {
              final old = chat.messages[optIdx];
              chat.messages[optIdx] = old.copyWith(
                id: realId,
                timestamp: realTs,
                status: MessageStatus.sent, // Sunucuya yazıldı: Tek gri tık
              );
              _deduplicateMessagesList(chat.messages);
              _saveChatsToLocalStorage();
              _emitRoomUpdate(partnerId);
              notifyListeners();
            }
          }
        }
      }

      // Alıcıya anında Apple APNs & OneSignal kapalı durum/arka plan push bildirimi gönder
      final senderName = _eventService.currentUser.name.isNotEmpty
          ? _eventService.currentUser.name
          : (_supabase.auth.currentUser?.userMetadata?['name'] as String? ?? 'Biri');

      final pushContent = text.contains('[audio:')
          ? '🎤 Sesli Mesaj'
          : (text.contains('[image:') ? '📷 Fotoğraf' : MessageModel.parseEncodedContent(text).cleanText);

      NotificationService().sendRemotePushNotification(
        receiverId: partnerId,
        senderName: senderName,
        content: pushContent,
        matchId: numericMatchId?.toString(),
        senderId: effectiveSenderId,
      );
    } catch (e) {
      debugPrint('[MessageService] ❌ INSERT HATASI: ${e.toString()}');
    }
  }

  Future<void> markAsRead(String chatId, {String? partnerId}) async {
    final lowerPartner = partnerId?.toLowerCase().trim();
    final lowerChatId = chatId.toLowerCase().trim();
    final chatIndex = _chats.indexWhere((c) =>
        c.id.toLowerCase() == lowerChatId ||
        c.participant.id.toLowerCase() == lowerChatId ||
        (lowerPartner != null && c.participant.id.toLowerCase() == lowerPartner));

    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];
      chat.unreadCount = 0;
      final currentId = currentUserId.trim();
      final lowerCurrent = currentId.toLowerCase();

      for (var m in chat.messages) {
        if (m.senderId.toLowerCase() != lowerCurrent) {
          m.status = MessageStatus.read;
        }
      }
      _saveChatsToLocalStorage();
      _emitRoomUpdate(chat.participant.id);
      notifyListeners();

      // Karşı tarafa gerçek zamanlı okundu sinyali gönder (Mavi tık için)
      try {
        _broadcastChannel?.sendBroadcastMessage(
          event: 'messages_read',
          payload: {
            'chat_id': chat.id,
            'reader_id': currentId,
            'partner_id': chat.participant.id,
          },
        );
      } catch (_) {}

      // Veritabanında da okundu olarak güncelle
      try {
        if (currentId.isNotEmpty && chat.participant.id.isNotEmpty) {
          await _supabase
              .from('messages')
              .update({'is_read': true})
              .eq('receiver_id', currentId)
              .eq('sender_id', chat.participant.id);
        }
      } catch (_) {}
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
