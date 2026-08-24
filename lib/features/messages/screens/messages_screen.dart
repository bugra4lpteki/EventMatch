import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/mock_match_service.dart';
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

  Future<bool?> _showEndMatchConfirmDialog(BuildContext context, String partnerName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sohbeti Sil / Eşleşmeyi Bitir', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '$partnerName ile sohbeti silmek istediğinizden emin misiniz? İleride birbirinizi tekrar keşfedip eşleşebilirsiniz.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.3),
        ),
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
            child: const Text('Sil ve Bitir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          final archivedChats = messageService.archivedChats;

          if (chats.isEmpty && archivedChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppColors.surface),
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
            onRefresh: () => messageService.reloadChats(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length + (archivedChats.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (archivedChats.isNotEmpty && index == 0) {
                  return _buildArchivedBanner(context, archivedChats.length);
                }

                final chatIndex = archivedChats.isNotEmpty ? index - 1 : index;
                final chat = chats[chatIndex];
                return _buildSlidableChatTile(context, chat, messageService);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchivedBanner(BuildContext context, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ArchivedChatsScreen(),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.archive_rounded, color: Color(0xFF818CF8), size: 20),
        ),
        title: Text(
          'Arşivlenmiş Sohbetler',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidableChatTile(BuildContext context, ChatModel chat, MockMessageService service) {
    final lastMsg = chat.lastMessage;
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

    return Slidable(
      key: ValueKey(chat.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.72,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              service.toggleMuteChat(chat.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(chat.isMuted
                      ? '${chat.participant.name} sesli moda alındı. 🔔'
                      : '${chat.participant.name} sessize alındı. 🔕'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            icon: chat.isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
            label: chat.isMuted ? 'Sesi Aç' : 'Sessiz',
          ),
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              service.toggleArchiveChat(chat.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${chat.participant.name} arşive alındı. 📦'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            icon: Icons.archive_rounded,
            label: 'Arşivle',
          ),
          SlidableAction(
            onPressed: (_) async {
              HapticFeedback.mediumImpact();
              final confirm = await _showEndMatchConfirmDialog(context, chat.participant.name);
              if (confirm == true) {
                await service.endMatchAndRemoveChat(chat.id, chat.participant.id);
                if (context.mounted) {
                  context.read<MockMatchService>().unmarkSeenUser(chat.participant.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${chat.participant.name} ile sohbet silindi.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Sil',
          ),
        ],
      ),
      child: ListTile(
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
            ],
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                chat.participant.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary,
                  fontWeight: chat.unreadCount > 0 ? FontWeight.w800 : FontWeight.bold,
                  fontSize: 15.5,
                  decoration: isBlocked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (chat.isMuted) ...[
              const SizedBox(width: 5),
              Icon(Icons.notifications_off_rounded, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
            ],
            if (isBlocked) ...[
              const SizedBox(width: 5),
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
    );
  }
}

class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Arşivlenmiş Sohbetler',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<MockMessageService>(
        builder: (context, service, child) {
          final archivedList = service.archivedChats;

          if (archivedList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: AppColors.surface),
                  const SizedBox(height: 16),
                  Text(
                    "Arşivlenmiş sohbet bulunmuyor.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: archivedList.length,
            itemBuilder: (context, index) {
              final chat = archivedList[index];
              final lastMsg = chat.lastMessage;

              return Slidable(
                key: ValueKey(chat.id),
                endActionPane: ActionPane(
                  motion: const BehindMotion(),
                  extentRatio: 0.5,
                  children: [
                    SlidableAction(
                      onPressed: (_) {
                        HapticFeedback.lightImpact();
                        service.toggleArchiveChat(chat.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${chat.participant.name} arşivden çıkarıldı. 📥'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      icon: Icons.unarchive_rounded,
                      label: 'Çıkar',
                    ),
                    SlidableAction(
                      onPressed: (_) async {
                        HapticFeedback.mediumImpact();
                        await service.endMatchAndRemoveChat(chat.id, chat.participant.id);
                        if (context.mounted) {
                          context.read<MockMatchService>().unmarkSeenUser(chat.participant.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${chat.participant.name} sohbeti silindi.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline_rounded,
                      label: 'Sil',
                    ),
                  ],
                ),
                child: ListTile(
                  onTap: () {
                    service.markAsRead(chat.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(chat: chat),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF1E2235),
                    backgroundImage: chat.participant.avatarUrl.startsWith('http') && !chat.participant.avatarUrl.contains('unsplash.com')
                        ? CachedNetworkImageProvider(chat.participant.avatarUrl)
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
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    chat.participant.name,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    lastMsg?.text ?? 'Mesaj yok',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white38),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

