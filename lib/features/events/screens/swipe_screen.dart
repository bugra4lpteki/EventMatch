import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../../../core/widgets/user_avatar.dart';
import '../services/mock_match_service.dart';
import '../services/mock_event_service.dart';
import '../models/user_model.dart';
import '../widgets/match_dialog.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/widgets/vip_paywall_sheet.dart';
import '../../messages/services/mock_message_service.dart';
import '../../messages/screens/chat_detail_screen.dart';
import '../../../core/widgets/report_block_sheet.dart';
import '../services/moderation_service.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();
  final TextEditingController _messageController = TextEditingController();
  int _refreshCount = 0;
  int _currentIndex = 0;
  final Set<String> _locallySwipedIds = {};
  final List<UserModel> _swipedHistory = [];

  Future<void> _handleUndoSwipe() async {
    final eventService = context.read<MockEventService>();
    final isVip = eventService.currentUser.hasActiveVip;

    if (!isVip) {
      VipPaywallSheet.show(
        context,
        initialFeature: VipFeature.undoSwipe,
      );
      return;
    }

    if (_swipedHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geri alınacak son bir profil bulunmuyor.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final lastSwiped = _swipedHistory.removeLast();
    _locallySwipedIds.remove(lastSwiped.id.toLowerCase().trim());
    final matchService = context.read<MockMatchService>();
    await matchService.undoSwipe(lastSwiped);

    if (mounted) {
      setState(() {
        _refreshCount++;
        _currentIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E1B18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.replay_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${lastSwiped.name} geri getirildi! 👑',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatches();
    });
  }

  void _loadMatches() {
    final matchService = context.read<MockMatchService>();
    // Supabase'den güncel verileri çek
    matchService.loadPotentialMatches();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MockMatchService>(
      builder: (context, matchService, child) {
        final eventService = context.watch<MockEventService>();
        final allItems = matchService.getPotentialMatches();
        final blockedIds = ModerationService().blockedUserIds;
        final items = allItems.where((user) {
          final cleanId = user.id.toLowerCase().trim();
          if (blockedIds.contains(user.id) || blockedIds.contains(cleanId)) return false;
          if (_locallySwipedIds.contains(cleanId)) return false;
          return true;
        }).toList();

        return Column(
          children: [
            // Top Bar with Title, VIP Quota & Actions
            _buildTopHeader(matchService, eventService),

            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.style_outlined, size: 64, color: AppColors.surface),
                      const SizedBox(height: 16),
                      Text(
                        'Şu an için yeni etkinlik katılımcısı bulunamadı.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          _locallySwipedIds.clear();
                          await matchService.loadPotentialMatches();
                          if (mounted) {
                            setState(() {
                              _refreshCount++;
                              _currentIndex = 0;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: const Text(
                          'Yenile',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (_swipedHistory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _handleUndoSwipe,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: const BorderSide(color: Colors.amber),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.replay_rounded, color: Colors.amber, size: 18),
                          label: const Text(
                            'Son Kartı Geri Al 👑',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Kartın sadece tam sağa veya tam sola belirgin şekilde çekilince kaybolması için
                      // threshold değerini genişliğin %45'i olarak ayarlıyoruz (küçük hareketlerde geri döner)
                      final swipeThreshold = (constraints.maxWidth * 0.45).clamp(160.0, 260.0);
                      return AppinioSwiper(
                        key: ValueKey('swipe_deck_$_refreshCount'),
                        controller: _swiperController,
                        cardCount: items.length,
                        backgroundCardCount: items.length > 1 ? 1 : 0,
                        backgroundCardOffset: Offset.zero,
                        backgroundCardScale: 1.0,
                        threshold: swipeThreshold,
                        swipeOptions: const SwipeOptions.only(left: true, right: true),
                        onSwipeEnd: (prev, target, activity) => _onSwipeEnd(prev, target, activity, items),
                        cardBuilder: (BuildContext context, int index) {
                          return _buildUserCard(items[index]);
                        },
                      );
                    },
                  ),
                ),
              ),
            // Message Input Bar (Replaces old buttons)
            _buildMessageInputBar(items),
          ],
        );
      },
    );
  }

  Widget _buildTopHeader(MockMatchService matchService, MockEventService eventService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161926).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Sol: İkon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.secondary.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(Icons.groups_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            // Orta: Başlık ve VIP / Kota durumu (Genişleyen ve esnek alan)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Etkinlik Katılımcıları',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<int>(
                    future: matchService.getRemainingDailySwipes(),
                    builder: (context, snapshot) {
                      final isVip = eventService.currentUser.hasActiveVip;
                      if (isVip) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            VipPaywallSheet.show(context);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'VIP Sınırsız',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFDE68A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final rem = snapshot.data ?? 50;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          VipPaywallSheet.show(context);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 14),
                            const SizedBox(width: 3),
                            Text(
                              '$rem / 50 Hak',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                'Yükselt',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFDE68A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Sağ: Geri Al (Undo) ve Yenile Butonları (Ferah ve belirgin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopActionButton(
                  icon: Icons.replay_rounded,
                  color: const Color(0xFFF59E0B),
                  tooltip: 'Geri Al (VIP)',
                  onTap: _handleUndoSwipe,
                ),
                const SizedBox(width: 8),
                _buildTopActionButton(
                  icon: Icons.refresh_rounded,
                  color: AppColors.primary,
                  tooltip: 'Profilleri Yenile',
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    _locallySwipedIds.clear();
                    await matchService.loadPotentialMatches();
                    if (mounted) {
                      setState(() {
                        _refreshCount++;
                        _currentIndex = 0;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Katılımcı profilleri yenilendi! 🔄'),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1E1E2E),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final bool hasValidPhoto = user.hasRealPhoto;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(user: user),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Avatar / Profile Photo Image or Gender-aware Hero Card
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: hasValidPhoto
                      ? AppImageWidget(
                          imageUrl: user.validAvatarUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          memCacheHeight: 800,
                        )
                      : UserHeroAvatarCard(
                          gender: user.gender,
                          name: user.name,
                        ),
                ),
              ),
              // Gradient Overlay (Sadece en alt %18'lik bantta hafif karartma)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.82, 0.92, 1.0],
                    ),
                  ),
                ),
              ),
              // Top Right Report & Block Button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    ReportBlockSheet.showOptionsModal(
                      context,
                      userId: user.id,
                      userName: user.name,
                      onUserBlocked: () {
                        _swiperController.swipeLeft();
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            // User Info (Fotoğrafa dokunulduğunda da profile gider, kompakt alt yerleşim)
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerifiedBadgeVisible) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 19, color: Color(0xFF38BDF8)),
                      ],
                      if (user.age != null && user.age!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          user.age!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.aboutMe != null && user.aboutMe!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      user.aboutMe!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  IconData _getTagIcon(String tag) {
    switch (tag.toLowerCase()) {
      case 'tiyatro':
        return Icons.theater_comedy;
      case 'spor':
        return Icons.sports_basketball;
      case 'konser':
        return Icons.music_note;
      case 'stand-up':
        return Icons.mic;
      case 'müzik':
        return Icons.music_video;
      case 'sanat':
        return Icons.palette;
      case 'techno':
        return Icons.surround_sound;
      case 'kahve':
        return Icons.coffee;
      case 'gaming':
        return Icons.videogame_asset;
      default:
        return Icons.star;
    }
  }



  Widget _buildMessageInputBar(List<UserModel> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final safeIndex = _currentIndex.clamp(0, items.length - 1);
    final currentItem = items[safeIndex];
    final String name = currentItem.name;

      return Container(
      padding: const EdgeInsets.only(bottom: 20.0, top: 4.0, left: 16.0, right: 16.0),
      child: Row(
        children: [
          // Undo Swipe Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.replay_rounded, color: Colors.amber, size: 19),
              tooltip: 'Son Kartı Geri Al (VIP)',
              onPressed: _handleUndoSwipe,
            ),
          ),
          // Message TextField
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMatchMessage(currentItem),
                decoration: InputDecoration(
                  hintText: '$name kişisine etkinlik mesajı yaz...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send Match Request Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              tooltip: 'Katılım İsteği & Mesaj Gönder',
              onPressed: () => _sendMatchMessage(currentItem),
            ),
          ),
        ],
      ),
    );
  }

  String? _pendingMessage;

  void _sendMatchMessage(dynamic item) async {
    final matchService = context.read<MockMatchService>();
    final canSwipe = await matchService.canSwipe();
    if (!canSwipe) {
      if (mounted) {
        VipPaywallSheet.show(context, initialFeature: VipFeature.undoSwipe);
      }
      return;
    }
    final messageText = _messageController.text.trim();
    _pendingMessage = messageText.isNotEmpty ? messageText : null;
    _messageController.clear();
    FocusScope.of(context).unfocus();
    _swiperController.swipeRight();
  }

  void _onSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity, List<UserModel> items) async {
    final matchService = context.read<MockMatchService>();
    final canSwipe = await matchService.canSwipe();
    if (!canSwipe) {
      if (mounted) {
        VipPaywallSheet.show(context, initialFeature: VipFeature.undoSwipe);
      }
      return;
    }
    if (previousIndex >= 0 && previousIndex < items.length) {
      final swipedItem = items[previousIndex];
      _locallySwipedIds.add(swipedItem.id.toLowerCase().trim());
      _swipedHistory.add(swipedItem);
    }
    setState(() {
      _currentIndex = targetIndex;
    });
    if (previousIndex < 0 || previousIndex >= items.length) return;
    final item = items[previousIndex];
    
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.right) {
        final messageToSend = _pendingMessage;
        _pendingMessage = null;
        final isMutualMatch = await matchService.swipeRight(item, initialMessage: messageToSend);
        if (isMutualMatch && mounted) {
          final msgService = context.read<MockMessageService>();
          final chat = msgService.createOrGetChatForUser(item, initialMessage: messageToSend);
          await msgService.reloadChats();
          
          if (!mounted) return;
          MatchDialog.show(
            context,
            matchedUser: item,
            onSendMessage: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(chat: chat),
                ),
              );
            },
          );
        }
      } else if (activity.direction == AxisDirection.left) {
        _pendingMessage = null;
        matchService.swipeLeft(item);
      }
    }
  }
}
