import 'package:flutter/material.dart';
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
            // Top Bar with Title and Refresh
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.style_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Eşleşme Keşfi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Kalan Kaydırma Kotası Rozeti
                      FutureBuilder<int>(
                        future: matchService.getRemainingDailySwipes(),
                        builder: (context, snapshot) {
                          final isVip = eventService.currentUser.hasActiveVip;
                          if (isVip) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.all_inclusive_rounded, color: Color(0xFFF59E0B), size: 14),
                                  SizedBox(width: 4),
                                  Text('VIP Sınırsız', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }
                          final rem = snapshot.data ?? 50;
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '⚡ $rem / 50 Hak',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                      // Geri Al (Undo) Button (VIP)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.replay_rounded, color: Colors.amber, size: 20),
                          tooltip: 'Geri Al (VIP)',
                          onPressed: _handleUndoSwipe,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'Profilleri Yenile',
                          onPressed: () async {
                            _locallySwipedIds.clear();
                            await matchService.loadPotentialMatches();
                            if (mounted) {
                              setState(() {
                                _refreshCount++;
                                _currentIndex = 0;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profiller yenilendi! 🔄'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.style_outlined, size: 64, color: AppColors.surface),
                      const SizedBox(height: 16),
                      Text(
                        'Şu an için yeni eşleşme bulunamadı.',
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
                  hintText: '$name kişisine mesaj yaz...',
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
              tooltip: 'Eşleşme İsteği & Mesaj Gönder',
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
