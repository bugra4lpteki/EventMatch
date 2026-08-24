import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../models/message_model.dart';
import '../services/mock_message_service.dart';
import '../../events/services/mock_event_service.dart';
import '../../profile/screens/user_profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  // 1. STREAM ASLA BUILD METODUNDA ÇAĞRILMAZ, initState'TE BAĞLANIR!
  late final Stream<List<MessageModel>> _messageStream;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _liveSyncTimer;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.chat.messages.length;

    // Aktif sohbet ID'sini bildir (Bu sohbet açıkken bildirim sesi/penceresi bastırılır)
    NotificationService().activeChatId = widget.chat.participant.id;

    // 2. Stream'i kalıcı olarak tek seferlik bağla
    final msgService = context.read<MockMessageService>();
    _messageStream = msgService.getMessagesStream(widget.chat.participant.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
      msgService.markAsRead(widget.chat.id);
      msgService.syncChatMessagesForPartner(widget.chat.participant.id);
    });

    // 1 saniyelik canlı senkronizasyon emniyet sübabı
    _liveSyncTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (mounted) {
        context.read<MockMessageService>().syncChatMessagesForPartner(widget.chat.participant.id);
      }
    });
  }

  @override
  void dispose() {
    NotificationService().activeChatId = null;
    _liveSyncTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuad,
      );
    } else {
      _scrollController.jumpTo(maxScroll);
    }
  }

  void _sendMessage(MockMessageService msgService, String currentChatId, bool isBlocked) {
    if (isBlocked) return;

    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      _messageController.clear();
      msgService.sendMessage(currentChatId, text, receiverUserId: widget.chat.participant.id);
      
      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollToBottom(animated: true);
      });
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, MockMessageService service, String currentChatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sohbeti Sil', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Bu sohbeti silmek istediğinizden emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await service.deleteChat(currentChatId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.chat.participant.name} ile sohbet silindi.')),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgService = context.watch<MockMessageService>();
    final isFollowing = msgService.isFollowing(widget.chat.participant.id);
    final isBlocked = msgService.isBlocked(widget.chat.participant.id);

    final currentChat = msgService.individualChats.firstWhere(
      (c) =>
          c.id == widget.chat.id ||
          c.participant.id.toLowerCase() == widget.chat.participant.id.toLowerCase(),
      orElse: () => widget.chat,
    );

    final currentUserObj = context.read<MockEventService>().currentUser;
    final myTags = currentUserObj.tags;
    final theirTags = currentChat.participant.tags;
    final commonTags = myTags.where((tag) => theirTags.contains(tag)).toList();

    String? matchInsightTitle;
    if (commonTags.isNotEmpty) {
      matchInsightTitle = "İkiniz de ${commonTags.take(3).join(', ')} seviyorsunuz!";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        elevation: 1,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(user: currentChat.participant),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage: currentChat.participant.avatarUrl.startsWith('http')
                    ? NetworkImage(currentChat.participant.avatarUrl)
                    : null,
                child: !currentChat.participant.avatarUrl.startsWith('http')
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            currentChat.participant.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary,
                              decoration: isBlocked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primary),
                        if (isFollowing) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Takip',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Çevrimiçi',
                          style: TextStyle(fontSize: 11, color: Colors.greenAccent.shade400, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: currentChat.participant),
                  ),
                );
              } else if (value == 'follow') {
                msgService.toggleFollowUser(currentChat.participant.id);
              } else if (value == 'block') {
                msgService.toggleBlockUser(currentChat.participant.id);
              } else if (value == 'delete') {
                _showDeleteConfirmDialog(context, msgService, currentChat.id);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Profili Görüntüle', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'follow',
                child: Row(
                  children: [
                    Icon(
                      isFollowing ? Icons.person_remove_rounded : Icons.person_add_alt_1_rounded,
                      color: isFollowing ? Colors.amber : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isFollowing ? 'Takibi Bırak' : 'Takip Et',
                      style: TextStyle(color: isFollowing ? Colors.amber : AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isBlocked ? 'Engeli Kaldır' : 'Kullanıcıyı Engelle',
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Sohbeti Sil', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isBlocked)
            Container(
              color: Colors.redAccent.withValues(alpha: 0.2),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bu kullanıcıyı engellediniz.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => msgService.toggleBlockUser(currentChat.participant.id),
                    child: const Text('Engeli Kaldır', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          if (matchInsightTitle != null && !isBlocked)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      matchInsightTitle,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          
          // 3. DOĞRUDAN STREAMBUILDER İLE CANLI MESAJ LİSTESİ
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messageStream,
              initialData: currentChat.messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        'STREAM HATA: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? currentChat.messages;

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom(animated: true);
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.surface),
                        const SizedBox(height: 12),
                        Text(
                          'Eşleşme sağlandı! 🎉',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İlk mesajı göndererek sohbete başla.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == msgService.currentUserId ||
                        message.senderId == 'me' ||
                        (msgService.currentUserId.isEmpty && message.senderId != currentChat.participant.id);

                    return _buildWhatsAppMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(msgService, currentChat.id, isBlocked),
        ],
      ),
    );
  }

  /// WhatsApp Tarzı Mesaj Balonu ve İletim Tıkları
  Widget _buildWhatsAppMessageBubble(MessageModel message, bool isMe) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6D28D9) : const Color(0xFF1F2232),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.white60,
                    fontSize: 10.5,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusTick(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp Tık İkonları (Gönderiliyor -> Gönderildi -> İletildi -> Okundu Çift Mavi Tık)
  Widget _buildStatusTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 12, color: Colors.white60);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF34B7F1));
    }
  }

  Widget _buildMessageComposer(MockMessageService msgService, String currentChatId, bool isBlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF171923),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !isBlocked,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: isBlocked ? '🚫 Kullanıcı engellendi' : 'Mesaj yaz...',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
                filled: true,
                fillColor: const Color(0xFF0D0E15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(msgService, currentChatId, isBlocked),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isBlocked ? null : () => _sendMessage(msgService, currentChatId, isBlocked),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isBlocked ? null : AppColors.primaryGradient,
                color: isBlocked ? Colors.grey : null,
                shape: BoxShape.circle,
                boxShadow: isBlocked
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
