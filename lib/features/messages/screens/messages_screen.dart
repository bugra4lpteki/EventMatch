import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  void _showChatOptions(BuildContext context, ChatModel chat, MockMessageService service) {
    final isFollowing = service.isFollowing(chat.participant.id);
    final isBlocked = service.isBlocked(chat.participant.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: chat.participant.avatarUrl.startsWith('http')
                      ? NetworkImage(chat.participant.avatarUrl)
                      : null,
                  child: !chat.participant.avatarUrl.startsWith('http')
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  chat.participant.name,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chat.participant.city ?? 'Etkinlik Sever',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                title: Text('Profili Görüntüle', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(user: chat.participant),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isFollowing ? Icons.person_remove_rounded : Icons.person_add_alt_1_rounded,
                  color: isFollowing ? Colors.amber : AppColors.primary,
                ),
                title: Text(
                  isFollowing ? 'Takibi Bırak' : 'Takip Et',
                  style: TextStyle(color: isFollowing ? Colors.amber : AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  service.toggleFollowUser(chat.participant.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFollowing
                          ? '${chat.participant.name} takipten çıkarıldı.'
                          : '${chat.participant.name} takip ediliyor! 🟢'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                  color: Colors.orangeAccent,
                ),
                title: Text(
                  isBlocked ? 'Engeli Kaldır' : 'Kullanıcıyı Engelle',
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  service.toggleBlockUser(chat.participant.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isBlocked
                          ? '${chat.participant.name} engeli kaldırıldı.'
                          : '${chat.participant.name} engellendi.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await _showDeleteConfirmDialog(context);
                  if (confirm == true) {
                    await service.deleteChat(chat.id);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sohbeti Sil', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Bu sohbeti silmek istediğinizden emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Mesajlar',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
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
      ),
      body: Consumer<MockMessageService>(
        builder: (context, messageService, child) {
          final chats = messageService.individualChats;
          return _buildChatList(context, chats, messageService);
        },
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

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => service.reloadChats(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          final lastMsg = chat.lastMessage;
          final isFollowing = service.isFollowing(chat.participant.id);
          final isBlocked = service.isBlocked(chat.participant.id);

          String timeStr = '';
          if (lastMsg != null) {
            final now = DateTime.now();
            if (lastMsg.timestamp.day == now.day &&
                lastMsg.timestamp.month == now.month &&
                lastMsg.timestamp.year == now.year) {
              timeStr = '${lastMsg.timestamp.hour.toString().padLeft(2, '0')}:${lastMsg.timestamp.minute.toString().padLeft(2, '0')}';
            } else {
              timeStr = '${lastMsg.timestamp.day}/${lastMsg.timestamp.month}';
            }
          }

          return Dismissible(
            key: Key('${chat.id}_${chat.participant.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) => _showDeleteConfirmDialog(context),
            onDismissed: (direction) {
              service.deleteChat(chat.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${chat.participant.name} ile sohbet silindi.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Colors.redAccent.withOpacity(0.8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text('Sohbeti Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            child: RepaintBoundary(
              child: ListTile(
                onLongPress: () => _showChatOptions(context, chat, service),
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
                        backgroundColor: const Color(0xFF1E2235),
                        backgroundImage: chat.participant.avatarUrl.startsWith('http') && !chat.participant.avatarUrl.contains('unsplash.com')
                            ? CachedNetworkImageProvider(
                                chat.participant.avatarUrl,
                                maxHeight: 120,
                                maxWidth: 120,
                              )
                            : null,
                        child: (!chat.participant.avatarUrl.startsWith('http') || chat.participant.avatarUrl.contains('unsplash.com'))
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    chat.participant.name.trim().isNotEmpty
                                        ? chat.participant.name.trim()[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (chat.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.participant.name,
                        style: TextStyle(
                          color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.w800 : FontWeight.bold,
                          fontSize: 15.5,
                          decoration: isBlocked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isFollowing) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Takip Ediliyor', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (isBlocked) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Engellendi', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  isBlocked
                      ? '🚫 Bu kullanıcı engellendi'
                      : lastMsg?.text ?? 'Eşleşme sağlandı! Sohbet başlatın.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isBlocked
                        ? Colors.redAccent.withValues(alpha: 0.7)
                        : (chat.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary),
                    fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13.5,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: chat.unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    if (chat.unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          '${chat.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

