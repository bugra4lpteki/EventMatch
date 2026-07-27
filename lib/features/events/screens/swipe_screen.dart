import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_match_service.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../widgets/vibe_check_widget.dart';
import '../services/mock_event_service.dart';
import '../widgets/match_dialog.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../messages/services/mock_message_service.dart';
import '../../messages/screens/chat_detail_screen.dart';

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
        final isDoubleDate = matchService.isDoubleDateMode;
        final items = isDoubleDate ? matchService.getPotentialGroups() : matchService.getPotentialMatches();

        return Column(
          children: [
            // Mode Toggle & Refresh Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => isDoubleDate ? matchService.toggleDoubleDateMode() : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isDoubleDate ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Center(
                                  child: Text(
                                    'Tekli',
                                    style: TextStyle(
                                      color: !isDoubleDate ? Colors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => !isDoubleDate ? matchService.toggleDoubleDateMode() : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDoubleDate ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.group,
                                        size: 16,
                                        color: isDoubleDate ? Colors.white : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Double Date',
                                        style: TextStyle(
                                          color: isDoubleDate ? Colors.white : AppColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                              backgroundColor: AppColors.surface,
                            ),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('Yenile', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await matchService.resetSwipes();
                              if (mounted) {
                                setState(() {
                                  _refreshCount++;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Test etkileşimleri sıfırlandı! Profiller yeniden yüklendi. 🔄'),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            icon: const Icon(Icons.restore, color: Colors.white),
                            label: const Text('Sıfırla & Yeniden Yükle', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 12.0),
                  child: AppinioSwiper(
                    key: ValueKey('${isDoubleDate}_${_refreshCount}_${items.length}'),
                    controller: _swiperController,
                    cardCount: items.length,
                    onSwipeEnd: (prev, target, activity) => _onSwipeEnd(prev, target, activity, items),
                    cardBuilder: (BuildContext context, int index) {
                      final item = items[index];
                      if (item is GroupModel) {
                        return _buildGroupCard(item);
                      } else {
                        return _buildUserCard(item as UserModel);
                      }
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

  Widget _buildGroupCard(GroupModel group) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Split Images
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  Expanded(
                    child: group.avatarUrl1.startsWith('http')
                        ? Image.network(group.avatarUrl1, fit: BoxFit.cover)
                        : Container(color: Colors.grey),
                  ),
                  const VerticalDivider(width: 2, color: Colors.white, thickness: 2),
                  Expanded(
                    child: group.avatarUrl2.startsWith('http')
                        ? Image.network(group.avatarUrl2, fit: BoxFit.cover)
                        : Container(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Info
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'DOUBLE DATE',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (group.groupBio != null)
                  Text(
                    group.groupBio!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: group.commonInterests.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final String photoUrl = user.avatarUrl.isNotEmpty
        ? user.avatarUrl
        : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=600';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Avatar / Profile Photo Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: photoUrl.startsWith('http')
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: Icon(Icons.person, size: 80, color: AppColors.primary),
                      ),
                    )
                  : Container(
                      color: AppColors.surface,
                      child: Icon(Icons.person, size: 80, color: AppColors.primary),
                    ),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Info Button Top Right
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
              ),
              tooltip: 'Profili Görüntüle',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: user),
                  ),
                );
              },
            ),
          ),
          // User Info
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: user),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Badge Icons
                    ...user.badges.map((badge) => Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Tooltip(
                            message: badge,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getBadgeIcon(badge),
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(width: 8),
                    Text(
                      user.age ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Vibe Check
                Consumer<MockEventService>(
                  builder: (context, eventService, child) {
                    final vibe = eventService.calculateVibe(user);
                    return VibeCheckWidget(
                      score: vibe['score'],
                      commonalities: vibe['commonalities'],
                      compact: true,
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (user.aboutMe != null)
                  Text(
                    user.aboutMe!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.tags
                      .take(5)
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3), 
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTagIcon(tag),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
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
          ),
        ],
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

  IconData _getBadgeIcon(String badge) {
    switch (badge) {
      case 'Sahne Tozu Yutmuş':
        return Icons.theater_comedy;
      case 'Sinema Sever':
        return Icons.movie_filter;
      case 'Müzik Tutkunu':
        return Icons.music_note;
      default:
        return Icons.emoji_events;
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
      padding: const EdgeInsets.only(bottom: 24.0, top: 4.0, left: 16.0, right: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Message Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('🎵 Konsere birlikte gidelim mi?'),
                const SizedBox(width: 6),
                _buildQuickChip('☕ Bir kahve içelim mi?'),
                const SizedBox(width: 6),
                _buildQuickChip('✨ Harika bir profil, selam!'),
                const SizedBox(width: 6),
                _buildQuickChip('🎭 Etkinlikte buluşalım!'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Input & Action Row
          Row(
            children: [
              // Pass Button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: Colors.white10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 24),
                  tooltip: 'Pas Geç',
                  onPressed: () {
                    _swiperController.swipeLeft();
                    _messageController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Message TextField
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.5),
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
                      color: AppColors.primary.withOpacity(0.4),
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

  Widget _buildQuickChip(String text) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _messageController.text = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _sendMatchMessage(dynamic item) async {
    final messageText = _messageController.text.trim();
    _messageController.clear();
    FocusScope.of(context).unfocus();

    if (item is UserModel) {
      final matchService = context.read<MockMatchService>();
      final isMutualMatch = await matchService.swipeRight(item, initialMessage: messageText);

      if (isMutualMatch && mounted) {
        final msgService = context.read<MockMessageService>();
        final chat = msgService.createOrGetChatForUser(item, initialMessage: messageText);
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
      } else if (mounted) {
        final textMsg = messageText.isNotEmpty
            ? '${item.name} kişisine mesajın gönderildi! 📩 Karşı taraf da seni beğenirse mesaj kutunuza düşecek.'
            : '${item.name} kişisine eşleşme isteği gönderildi! Karşı taraf da beğendiğinde mesaj kutunuza düşecek.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(textMsg),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
        _swiperController.swipeRight();
      }
    } else if (item is GroupModel) {
      _swiperController.swipeRight();
    }
  }

  void _onSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity, List<dynamic> items) async {
    setState(() {
      _currentIndex = targetIndex;
    });
    final matchService = context.read<MockMatchService>();
    final item = items[previousIndex];
    final itemName = item is UserModel ? item.name : (item as GroupModel).name;
    
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.right) {
        if (item is UserModel) {
          final isMutualMatch = await matchService.swipeRight(item);
          if (isMutualMatch && mounted) {
            final msgService = context.read<MockMessageService>();
            final chat = msgService.createOrGetChatForUser(item);
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
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$itemName kişisine eşleşme isteği gönderildi!')),
            );
          }
        }
      } else if (activity.direction == AxisDirection.left) {
        if (item is UserModel) {
          matchService.swipeLeft(item);
        }
      }
    }
  }
}
