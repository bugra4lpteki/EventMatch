import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  void _sendMessage() {
    final msgService = context.read<MockMessageService>();
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

  @override
  Widget build(BuildContext context) {
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
                        Text(
                          widget.chat.participant.name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: AppColors.primary),
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
                  if (widget.chat.participant.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.chat.participant.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 0.5),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      body: Consumer<MockMessageService>(
        builder: (context, messageService, child) {
          // Re-fetch chat from service to get real-time updates
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
              if (isExpired)
                Container(
                  color: Colors.redAccent.withOpacity(0.15),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_clock, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Bu sohbetin süresi dolmuştur.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (matchInsightTitle != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.9), // Glassmorphism Look
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
              _buildMessageComposer(isExpired),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
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
        child: Text(
          message.text,
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageComposer(bool isExpired) {
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
              enabled: !isExpired,
              style: TextStyle(color: isExpired ? AppColors.textSecondary : AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: isExpired ? 'Sohbet süresi doldu' : 'Mesaj yaz...',
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
            onTap: isExpired ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isExpired ? Colors.grey : AppColors.primary,
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
