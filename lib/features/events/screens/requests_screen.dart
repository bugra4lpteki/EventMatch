import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../models/match_request.dart';
import '../services/mock_match_service.dart';
import '../widgets/match_dialog.dart';
import '../../messages/services/mock_message_service.dart';
import '../../messages/screens/chat_detail_screen.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

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
                      ClipOval(
                        child: hasRealPhoto
                            ? AppImageWidget(
                                imageUrl: req.fromUser.avatarUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                memCacheWidth: 120,
                                memCacheHeight: 120,
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    req.fromUser.name.isNotEmpty ? req.fromUser.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.fromUser.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Seninle tanışmak istiyor!",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () {
                            matchService.rejectRequest(req);
                          },
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final success = await matchService.acceptRequest(req);
                            if (success && context.mounted) {
                              final msgService = context.read<MockMessageService>();
                              final chat = msgService.createOrGetChatForUser(req.fromUser);

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
