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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(MockMessageService msgService, bool isBlocked) {
    if (isBlocked) return;

    final currentChat = msgService.individualChats.followedBy(msgService.eventChats)
        .firstWhere((c) => c.id == widget.chat.id, orElse: () => widget.chat);
    final isExpired = currentChat.expiresAt != null && currentChat.expiresAt!.isBefore(DateTime.now());
    if (isExpired) return;

    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      msgService.sendMessage(widget.chat.id, text);
      _messageController.clear();
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, MockMessageService service) {
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
              Navigator.pop(context); // Pop dialog
              await service.deleteChat(widget.chat.id);
              if (mounted) {
                Navigator.pop(context); // Pop chat detail back to list
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(user: widget.chat.participant),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage: widget.chat.participant.avatarUrl.startsWith('http')
                    ? NetworkImage(widget.chat.participant.avatarUrl)
                    : null,
                child: !widget.chat.participant.avatarUrl.startsWith('http')
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
                            widget.chat.participant.name,
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
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                        if (isFollowing) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Takip Ediliyor', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    if (widget.chat.isEventBased && widget.chat.relatedEvent != null)
                      Row(
                        children: [
                          Icon(Icons.event, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.chat.relatedEvent!.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.primary),
                            ),
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
                    builder: (context) => UserProfileScreen(user: widget.chat.participant),
                  ),
                );
              } else if (value == 'follow') {
                msgService.toggleFollowUser(widget.chat.participant.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFollowing
                        ? '${widget.chat.participant.name} takipten çıkarıldı.'
                        : '${widget.chat.participant.name} takip ediliyor! 🟢'),
                  ),
                );
              } else if (value == 'block') {
                msgService.toggleBlockUser(widget.chat.participant.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isBlocked
                        ? '${widget.chat.participant.name} engeli kaldırıldı.'
                        : '${widget.chat.participant.name} engellendi.'),
                  ),
                );
              } else if (value == 'delete') {
                _showDeleteConfirmDialog(context, msgService);
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
      body: Consumer<MockMessageService>(
        builder: (context, messageService, child) {
          final currentChat = messageService.individualChats.followedBy(messageService.eventChats)
              .firstWhere((c) => c.id == widget.chat.id, orElse: () => widget.chat);

          final currentUserObj = context.read<MockEventService>().currentUser;
          final myTags = currentUserObj.tags;
          final theirTags = widget.chat.participant.tags;
          final commonTags = myTags.where((tag) => theirTags.contains(tag)).toList();
          
          String? matchInsightTitle;
          if (commonTags.isNotEmpty) {
            matchInsightTitle = "İkiniz de ${commonTags.join(', ')} seviyorsunuz!";
          } else if (currentUserObj.age != null && widget.chat.participant.age != null) {
            final myAge = int.tryParse(currentUserObj.age!);
            final theirAge = int.tryParse(widget.chat.participant.age!);
            if (myAge != null && theirAge != null && (myAge - theirAge).abs() <= 2) {
              matchInsightTitle = "Yaşlarınız birbirine çok yakın!";
            }
          }

          final isExpired = currentChat.expiresAt != null && currentChat.expiresAt!.isBefore(DateTime.now());

          return Column(
            children: [
              if (isBlocked)
                Container(
                  color: Colors.redAccent.withOpacity(0.2),
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
                        onPressed: () => messageService.toggleBlockUser(widget.chat.participant.id),
                        child: const Text('Engeli Kaldır', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              else if (isExpired)
                Container(
                  color: Colors.redAccent.withOpacity(0.15),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_clock, color: Colors.redAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Bu sohbetin süresi dolmuştur.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (matchInsightTitle != null && !isBlocked)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)
                    ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          matchInsightTitle,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: currentChat.messages.length,
                  itemBuilder: (context, index) {
                    final message = currentChat.messages[index];
                    final isMe = message.senderId == messageService.currentUserId;

                    return _buildMessageBubble(message, isMe);
                  },
                ),
              ),
              _buildMessageComposer(messageService, isExpired, isBlocked),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: isMe ? null : Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
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
                  const Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer(MockMessageService msgService, bool isExpired, bool isBlocked) {
    final isDisabled = isExpired || isBlocked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 12,
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
              enabled: !isDisabled,
              style: TextStyle(color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: isBlocked
                    ? '🚫 Kullanıcı engellendi'
                    : isExpired
                        ? 'Sohbet süresi doldu'
                        : 'Mesaj yaz...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isDisabled ? null : () => _sendMessage(msgService, isBlocked),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
