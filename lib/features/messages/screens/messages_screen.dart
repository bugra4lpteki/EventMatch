import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_message_service.dart';
import '../models/message_model.dart';
import 'chat_detail_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MockMessageService>().reloadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            'Mesajlar',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Mesajları Yenile',
              onPressed: () {
                context.read<MockMessageService>().reloadChats();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mesajlar yenileniyor... 🔄'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
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

  Widget _buildChatList(
      BuildContext context, List<ChatModel> chats, MockMessageService service) {
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.surface),
            const SizedBox(height: 16),
            Text(
              "Henüz hiç eşleşmeniz veya mesajınız yok.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final lastMsg = chat.lastMessage;
        final isExpired =
            chat.expiresAt != null && chat.expiresAt!.isBefore(DateTime.now());

        return ListTile(
          onTap: () {
            service.markAsRead(chat.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(chat: chat),
              ),
            );
          },
          leading: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(user: chat.participant),
                ),
              );
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surface,
                  backgroundImage: chat.participant.avatarUrl.startsWith('http')
                      ? NetworkImage(chat.participant.avatarUrl)
                      : null,
                  child: !chat.participant.avatarUrl.startsWith('http')
                      ? Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                if (chat.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: Text(
            chat.participant.name,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            lastMsg?.text ?? 'Eşleşme sağlandı! Sohbet başlatın.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isExpired ? Colors.redAccent : AppColors.textSecondary,
            ),
          ),
          trailing: chat.expiresAt != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.amber),
                    const SizedBox(height: 2),
                    Text(
                      isExpired ? 'Süre doldu' : 'Aktif',
                      style: const TextStyle(fontSize: 10, color: Colors.amber),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}
