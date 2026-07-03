import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_message_service.dart';
import '../models/message_model.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text('Mesajlar', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: "Bireysel"),
              Tab(text: "Etkinlikler"),
            ],
          ),
        ),
        body: Consumer<MockMessageService>(
          builder: (context, messageService, child) {
            final indChats = messageService.individualChats;
            final evtChats = messageService.eventChats;

            return TabBarView(
              children: [
                _buildChatList(context, indChats, messageService),
                _buildChatList(context, evtChats, messageService),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, List<ChatModel> chats, MockMessageService service) {
    if (chats.isEmpty) {
      return Center(child: Text("Henüz hiç mesajınız yok.", style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final lastMsg = chat.lastMessage;
        
        final isExpired = chat.expiresAt != null && chat.expiresAt!.isBefore(DateTime.now());

        return ListTile(
          onTap: () {
            service.markAsRead(chat.id);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatDetailScreen(chat: chat)
            ));
          },
          leading: Opacity(
            opacity: isExpired ? 0.6 : 1.0,
            child: CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(chat.participant.avatarUrl),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                chat.participant.name,
                style: TextStyle(
                  color: isExpired ? AppColors.textSecondary : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (lastMsg != null)
                Text(
                  _formatTime(lastMsg.timestamp),
                  style: TextStyle(
                    color: chat.unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chat.isEventBased && chat.relatedEvent != null)
                Text(
                  chat.relatedEvent!.title,
                  style: TextStyle(
                    color: isExpired ? AppColors.textSecondary.withOpacity(0.5) : AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Row(
                children: [
                  if (isExpired) ...[
                    Icon(Icons.lock_outline, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Süre Doldu - ',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (lastMsg != null)
                    Expanded(
                      child: Text(
                        lastMsg.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isExpired 
                              ? AppColors.textSecondary.withOpacity(0.6) 
                              : (chat.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary),
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          trailing: isExpired
              ? Icon(Icons.lock_outline, color: Colors.grey, size: 20)
              : (chat.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        chat.unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    }
    return "${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}";
  }
}
