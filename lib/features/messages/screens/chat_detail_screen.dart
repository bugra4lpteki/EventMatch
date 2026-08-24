import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _liveSyncTimer;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.chat.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
      final msgService = context.read<MockMessageService>();
      msgService.markAsRead(widget.chat.id);
      msgService.syncChatMessagesForPartner(widget.chat.participant.id);
    });

    // Her 2 saniyede bir arka planda hızlı senkronizasyon (Zero-lag güvencesi)
    _liveSyncTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (mounted) {
        context.read<MockMessageService>().syncChatMessagesForPartner(widget.chat.participant.id);
      }
    });
  }

  @override
  void dispose() {
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

    if (currentChat.messages.length != _lastMessageCount) {
      _lastMessageCount = currentChat.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: true);
      });
    }

    final currentUserObj = context.read<MockEventService>().currentUser;
    final myTags = currentUserObj.tags;
    final theirTags = currentChat.participant.tags;
    final commonTags = myTags.where((tag) => theirTags.contains(tag)).toList();

    String? matchInsightTitle;
    if (commonTags.isNotEmpty) {
      matchInsightTitle = "İkiniz de ${commonTags.take(3).join(', ')} seviyorsunuz!";
    } else if (currentUserObj.age != null && currentChat.participant.age != null) {
      final myAge = int.tryParse(currentUserObj.age!);
      final theirAge = int.tryParse(currentChat.participant.age!);
      if (myAge != null && theirAge != null && (myAge - theirAge).abs() <= 2) {
        matchInsightTitle = "Yaşlarınız birbirine çok yakın! 🎯";
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    if (currentChat.isEventBased && currentChat.relatedEvent != null)
                      Row(
                        children: [
                          Icon(Icons.event, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              currentChat.relatedEvent!.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: AppColors.primary),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Çevrimiçi',
                        style: TextStyle(fontSize: 11, color: Colors.greenAccent.shade400),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFollowing
                        ? '${currentChat.participant.name} takipten çıkarıldı.'
                        : '${currentChat.participant.name} takip ediliyor! 🟢'),
                  ),
                );
              } else if (value == 'block') {
                msgService.toggleBlockUser(currentChat.participant.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isBlocked
                        ? '${currentChat.participant.name} engeli kaldırıldı.'
                        : '${currentChat.participant.name} engellendi.'),
                  ),
                );
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
          Expanded(
            child: currentChat.messages.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: currentChat.messages.length,
                    itemBuilder: (context, index) {
                      final message = currentChat.messages[index];
                      final isMe = message.senderId == msgService.currentUserId ||
                          message.senderId == 'me' ||
                          (msgService.currentUserId.isEmpty && message.senderId != currentChat.participant.id);

                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          _buildMessageComposer(msgService, currentChat.id, isBlocked),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isMe ? null : Border.all(color: Colors.white10, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 14.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer(MockMessageService msgService, String currentChatId, bool isBlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: Colors.white10)),
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
              style: TextStyle(color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: isBlocked ? '🚫 Kullanıcı engellendi' : 'Mesaj yaz...',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                filled: true,
                fillColor: AppColors.background,
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
                color: isBlocked ? Colors.grey : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
