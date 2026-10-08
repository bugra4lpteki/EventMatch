import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/widgets/vip_paywall_sheet.dart';
import '../models/match_request.dart';
import '../../../core/services/in_app_review_service.dart';
import '../services/mock_match_service.dart';
import '../widgets/match_dialog.dart';
import '../../messages/services/mock_message_service.dart';
import '../../messages/screens/chat_detail_screen.dart';
import '../../../services/notification_service.dart';
import '../services/mock_event_service.dart';
import '../../../core/widgets/report_block_sheet.dart';

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
    final eventService = context.watch<MockEventService>();
    final currentUser = eventService.currentUser;
    final hasVip = currentUser.hasActiveVip;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Katılım İstekleri',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.workspace_premium_rounded,
              color: hasVip ? const Color(0xFFFBBF24) : Colors.white38,
            ),
            tooltip: 'EventMatch VIP',
            onPressed: () => VipPaywallSheet.show(context, initialFeature: VipFeature.seeLikes),
          ),
        ],
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
                    itemCount: requests.length + 1,
                    itemBuilder: (context, index) {
                      // 0. Header: VIP Promotional / Status Card
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () => VipPaywallSheet.show(
                            context,
                            initialFeature: VipFeature.seeLikes,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: hasVip
                                    ? [const Color(0xFF2E2405), const Color(0xFF191301)]
                                    : [const Color(0xFF261D04), const Color(0xFF130E02)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: hasVip ? 0.7 : 0.4),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasVip ? '👑 VIP Aktif: Tüm Katılım İstekleri Görünür' : 'Katılım İsteklerini Gör 👑',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFFDE68A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasVip
                                            ? '${requests.length} kişi seninle etkinliğe katılmak istiyor.'
                                            : 'Katılım isteklerini öncelikli görmek için EventMatch VIP\'ye geç!',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFFFDE68A), size: 20),
                              ],
                            ),
                          ),
                        );
                      }

                      final req = requests[index - 1];
                      final fromUser = req.fromUser;
                      final displayName = hasVip
                          ? fromUser.name
                          : (fromUser.name.isNotEmpty
                              ? '${fromUser.name[0]}***'
                              : 'Kullanıcı');

                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasVip
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                                  : AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar: If not VIP, blur photo with lock icon
                              GestureDetector(
                                onTap: () {
                                  if (!hasVip) {
                                    VipPaywallSheet.show(context, initialFeature: VipFeature.seeLikes);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => UserProfileScreen(user: fromUser)),
                                    );
                                  }
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (!hasVip)
                                      ClipOval(
                                        child: ImageFiltered(
                                          imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                          child: UserAvatar(
                                            user: fromUser,
                                            radius: 28,
                                          ),
                                        ),
                                      )
                                    else
                                      UserAvatar(
                                        user: fromUser,
                                        radius: 28,
                                      ),
                                    if (!hasVip)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                                        ),
                                        child: const Icon(
                                          Icons.lock_rounded,
                                          color: Color(0xFFFBBF24),
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (hasVip && fromUser.isVerifiedBadgeVisible) ...[
                                          const SizedBox(width: 5),
                                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF38BDF8)),
                                        ],
                                        if (fromUser.hasActiveVip) ...[
                                          const SizedBox(width: 5),
                                          const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFFFBBF24)),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      hasVip
                                          ? (req.message != null && req.message!.trim().isNotEmpty
                                              ? '💬 "${req.message!.trim()}"'
                                              : "Seninle etkinliğe katılmak istiyor!")
                                          : '🔒 Profil gizlendi. Görmek için dokun.',
                                      style: TextStyle(
                                        color: hasVip ? AppColors.textSecondary : const Color(0xFFFDE68A).withValues(alpha: 0.8),
                                        fontSize: 12,
                                        fontStyle: hasVip && req.message != null && req.message!.trim().isNotEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Actions: If not VIP, button opens VIP Paywall
                              if (!hasVip)
                                ElevatedButton.icon(
                                  onPressed: () => VipPaywallSheet.show(context, initialFeature: VipFeature.seeLikes),
                                  icon: const Icon(Icons.lock_open_rounded, size: 14, color: Colors.black),
                                  label: const Text('Gör 👑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
                                      tooltip: 'Şikayet Et / Engelle',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        ReportBlockSheet.showOptionsModal(
                                          context,
                                          userId: fromUser.id,
                                          userName: fromUser.name,
                                          onUserBlocked: () async {
                                            await matchService.rejectRequest(req);
                                            if (context.mounted) {
                                              context.read<MockMessageService>().reloadChats();
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
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
                                          InAppReviewService().triggerMatchSuccessReview();
                                          final myName = context.read<MockEventService>().currentUser.name;
                                          NotificationService().sendRemotePushNotification(
                                            receiverId: req.fromUser.id,
                                            senderName: myName.isNotEmpty ? myName : 'Biri',
                                            content: 'Katılım isteğini kabul etti! 🎉 Hemen sohbete başlayabilirsin.',
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
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: const Text("Kabul Et", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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

