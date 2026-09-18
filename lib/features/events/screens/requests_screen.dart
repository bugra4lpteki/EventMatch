import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../models/match_request.dart';
import '../services/mock_match_service.dart';
import '../widgets/match_dialog.dart';
import '../../messages/services/mock_message_service.dart';
import '../../messages/screens/chat_detail_screen.dart';
import '../../../services/notification_service.dart';
import '../services/mock_event_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MockMatchService>().loadIncomingRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Eşleşme İstekleri',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<MockMatchService>(
        builder: (context, matchService, child) {
          final rawRequests = matchService.incomingRequests;
          final seenKeys = <String>{};
          final requests = <MatchRequest>[];

          for (var r in rawRequests) {
            final key = '${r.fromUser.id}_${r.fromUser.name}'.toLowerCase();
            if (!seenKeys.contains(key) && !seenKeys.contains(r.fromUser.id.toLowerCase())) {
              seenKeys.add(key);
              seenKeys.add(r.fromUser.id.toLowerCase());
              requests.add(r);
            }
          }

          return RefreshIndicator(
            onRefresh: () => matchService.loadIncomingRequests(),
            color: AppColors.primary,
            child: requests.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: AppColors.surface),
                            const SizedBox(height: 16),
                            Text(
                              "Şu an bekleyen istek yok.",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final hasRealPhoto = req.fromUser.avatarUrl.isNotEmpty &&
                  req.fromUser.avatarUrl.startsWith('http') &&
                  !req.fromUser.avatarUrl.contains('unsplash.com');
              return RepaintBoundary(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        user: req.fromUser,
                        radius: 30,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(user: req.fromUser),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  req.fromUser.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (req.fromUser.isVerified) ...[
                                const SizedBox(width: 5),
                                const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF38BDF8)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            req.message != null && req.message!.trim().isNotEmpty
                                ? '💬 "${req.message!.trim()}"'
                                : "Seninle eşleşmek istiyor!",
                            style: TextStyle(
                              color: req.message != null && req.message!.trim().isNotEmpty
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              fontStyle: req.message != null && req.message!.trim().isNotEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () async {
                            await matchService.rejectRequest(req);
                            if (context.mounted) {
                              context.read<MockMessageService>().reloadChats();
                            }
                          },
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final success = await matchService.acceptRequest(req);
                            if (success && context.mounted) {
                              final myName = context.read<MockEventService>().currentUser.name;
                              NotificationService().sendRemotePushNotification(
                                receiverId: req.fromUser.id,
                                senderName: myName.isNotEmpty ? myName : 'Biri',
                                content: 'Eşleşme isteğini kabul etti! 🎉 Hemen sohbete başlayabilirsin.',
                              );

                              final msgService = context.read<MockMessageService>();
                              final chat = msgService.createOrGetChatForUser(
                                req.fromUser,
                                initialMessage: req.message,
                              );
                              await msgService.reloadChats();
                              if (!context.mounted) return;

                              MatchDialog.show(
                                context,
                                matchedUser: req.fromUser,
                                onSendMessage: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ChatDetailScreen(chat: chat),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Kabul Et",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  ),
);
}
}
