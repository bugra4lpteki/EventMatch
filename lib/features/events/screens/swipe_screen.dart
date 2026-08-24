import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../services/mock_match_service.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../widgets/match_dialog.dart';
import '../../profile/screens/user_profile_screen.dart';
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
        final allItems = matchService.getPotentialMatches();
        final blockedIds = ModerationService().blockedUserIds;
        final items = allItems.where((item) {
          if (item is UserModel) return !blockedIds.contains(item.id);
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
                        await matchService.loadPotentialMatches();
                        if (mounted) {
                          setState(() {
                            _refreshCount++;
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
                          await matchService.loadPotentialMatches();
                          if (mounted) {
                            setState(() {
                              _refreshCount++;
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
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
                  child: AppinioSwiper(
                    key: ValueKey('single_${_refreshCount}_${items.length}'),
                    controller: _swiperController,
                    cardCount: items.length,
                    backgroundCardCount: 1,
                    backgroundCardOffset: Offset.zero,
                    backgroundCardScale: 1.0,
                    onSwipeEnd: (prev, target, activity) => _onSwipeEnd(prev, target, activity, items),
                    cardBuilder: (BuildContext context, int index) {
                      return _buildUserCard(items[index] as UserModel);
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
    final bool hasValidPhoto = user.avatarUrl.isNotEmpty && user.avatarUrl.startsWith('http');
    final String initialLetter = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';

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
              // Avatar / Profile Photo Image with memory limits or Stylish Default Avatar
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: hasValidPhoto
                      ? AppImageWidget(
                          imageUrl: user.avatarUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          memCacheHeight: 800,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E2235),
                                AppColors.primary.withValues(alpha: 0.35),
                                const Color(0xFF131522),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.primaryGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      initialLetter,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: user.tags
                        .take(4)
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2), 
                                    width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getTagIcon(tag),
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    tag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
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



  Widget _buildMessageInputBar(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final safeIndex = _currentIndex.clamp(0, items.length - 1);
    final currentItem = items[safeIndex];
    final String name = currentItem is UserModel
        ? currentItem.name
        : (currentItem is GroupModel ? currentItem.name : 'Kullanıcı');

    return Container(
      padding: const EdgeInsets.only(bottom: 20.0, top: 4.0, left: 16.0, right: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Quick Message Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickChip('Konsere gidelim mi?', '🎵'),
                const SizedBox(width: 8),
                _buildQuickChip('Kahve içelim mi?', '☕'),
                const SizedBox(width: 8),
                _buildQuickChip('Selam, tanışalım mı?', '✨'),
                const SizedBox(width: 8),
                _buildQuickChip('Etkinlikte buluşalım!', '🎭'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Input & Action Row
          Row(
            children: [
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
                  tooltip: 'Mesaj Gönder & Beğen',
                  onPressed: () => _sendMatchMessage(currentItem),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text, String emoji) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _messageController.text = text;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String? _pendingMessage;

  void _sendMatchMessage(dynamic item) {
    final messageText = _messageController.text.trim();
    _pendingMessage = messageText.isNotEmpty ? messageText : null;
    _messageController.clear();
    FocusScope.of(context).unfocus();
    _swiperController.swipeRight();
  }

  void _onSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity, List<dynamic> items) async {
    setState(() {
      _currentIndex = targetIndex;
    });
    final matchService = context.read<MockMatchService>();
    if (previousIndex < 0 || previousIndex >= items.length) return;
    final item = items[previousIndex];
    
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.right) {
        if (item is UserModel) {
          final messageToSend = _pendingMessage;
          _pendingMessage = null;
          final isMutualMatch = await matchService.swipeRight(item, initialMessage: messageToSend);
          if (isMutualMatch && mounted) {
            final msgService = context.read<MockMessageService>();
            final chat = msgService.createOrGetChatForUser(item, initialMessage: messageToSend);
            await msgService.reloadChats();
            
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
        }
      } else if (activity.direction == AxisDirection.left) {
        _pendingMessage = null;
        if (item is UserModel) {
          matchService.swipeLeft(item);
        }
      }
    }
  }
}
