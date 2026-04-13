import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../../events/models/user_model.dart';
import '../../events/models/event_model.dart';
import '../../events/services/mock_event_service.dart';

class MockMessageService extends ChangeNotifier {
  final MockEventService _eventService;
  
  MockMessageService(this._eventService) {
    _initializeMockData();
  }

  final String currentUserId = 'user_1'; // Assuming logged in user is user_1
  
  List<ChatModel> _chats = [];

  List<ChatModel> get individualChats => 
      _chats.where((c) => !c.isEventBased).toList();

  List<ChatModel> get eventChats => 
      _chats.where((c) => c.isEventBased).toList();

  void _initializeMockData() {
    // Some dummy users
    final u2 = UserModel(id: 'u2', name: 'Ayşe Yılmaz', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=100', age: '24', aboutMe: 'Sahne sanatları aşığı!', tags: ['Tiyatro', 'Müzikal']);
    final u3 = UserModel(id: 'u3', name: 'Caner Demir', avatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?auto=format&fit=crop&q=80&w=100', age: '28', aboutMe: 'Tiyatro candır!', tags: ['Stand-up', 'Kahve', 'Gezgin']);
    final u4 = UserModel(id: 'u4', name: 'Zeynep Kaya', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=100', age: '27', aboutMe: 'Gülmeyi çok seviyorum.', tags: ['Sinema', 'Yoga', 'Gece Hayatı']);

    // Fetch an event from the event service safely (if exists)
    final allAdminEvents = _eventService.getAdminEvents();
    final ahududuEvent = allAdminEvents.firstWhere(
      (e) => e.title.contains('Ahududu'), 
      orElse: () => EventModel(id: 'dummy', title: 'Test Etkinlik', category: 'Tiyatro', location: 'X', dateTime: DateTime.now(), description: 'Y', imageUrl: 'assets/images/ahududu.jpeg'),
    );

    final kacParaEvent = allAdminEvents.firstWhere(
      (e) => e.title.contains('Kaç Para'), 
      orElse: () => EventModel(id: 'dummy2', title: 'Test Etkinlik 2', category: 'Tiyatro', location: 'X', dateTime: DateTime.now(), description: 'Y', imageUrl: 'assets/images/kac_para_bi_fon.jpeg'),
    );

    _chats = [
      // Individual Chat
      ChatModel(
        id: 'chat_1',
        participant: u3,
        isEventBased: false,
        unreadCount: 1,
        messages: [
          MessageModel(id: 'm1', senderId: 'u3', text: 'Selam! Naber?', timestamp: DateTime.now().subtract(const Duration(minutes: 40))),
          MessageModel(id: 'm2', senderId: currentUserId, text: 'İyidir senden?', timestamp: DateTime.now().subtract(const Duration(minutes: 35))),
          MessageModel(id: 'm3', senderId: 'u3', text: 'Ben de iyiyim, hafta sonu planın var mı?', timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
        ],
      ),
      // Event-based Chat 1
      ChatModel(
        id: 'chat_2',
        participant: u2,
        isEventBased: true,
        relatedEvent: ahududuEvent,
        unreadCount: 0,
        messages: [
          MessageModel(id: 'm1', senderId: 'u2', text: 'Ahududu oyununa ben de bilet aldım, çok heyecanlıyım!', timestamp: DateTime.now().subtract(const Duration(days: 1))),
          MessageModel(id: 'm2', senderId: currentUserId, text: 'Evet ben de! Belki fuayede karşılaşırız.', timestamp: DateTime.now().subtract(const Duration(hours: 2))),
        ],
      ),
      // Event-based Chat 2
      ChatModel(
        id: 'chat_3',
        participant: u4,
        isEventBased: true,
        relatedEvent: kacParaEvent,
        unreadCount: 2,
        messages: [
          MessageModel(id: 'm1', senderId: 'u4', text: 'Merhaba, bu etkinliğe yalnız mı gidiyorsun?', timestamp: DateTime.now().subtract(const Duration(minutes: 10))),
          MessageModel(id: 'm2', senderId: 'u4', text: 'Öncesinde kahve içmek istersin belki diye yazdım 😊', timestamp: DateTime.now().subtract(const Duration(minutes: 9))),
        ],
      ),
    ];
  }

  void sendMessage(String chatId, String text) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex >= 0) {
      final newMessage = MessageModel(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: currentUserId,
        text: text,
        timestamp: DateTime.now(),
      );
      _chats[chatIndex].messages.add(newMessage);
      
      // Move this chat to the top
      final chat = _chats.removeAt(chatIndex);
      _chats.insert(0, chat);
      
      notifyListeners();
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
