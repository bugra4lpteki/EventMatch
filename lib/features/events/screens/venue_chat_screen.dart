import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../models/event_model.dart';
import '../services/mock_event_service.dart';

/// Floating Reaction Particle Model for Streamer Live Chat
class _FloatingReaction {
  final String id;
  final String emoji;
  final double startX;
  final double speed;
  final double wobbleSpeed;
  final double wobbleAmount;
  final double scale;
  final DateTime createdAt;

  _FloatingReaction({
    required this.id,
    required this.emoji,
    required this.startX,
    required this.speed,
    required this.wobbleSpeed,
    required this.wobbleAmount,
    required this.scale,
    required this.createdAt,
  });
}

class VenueChatScreen extends StatefulWidget {
  final EventModel event;

  const VenueChatScreen({super.key, required this.event});

  @override
  State<VenueChatScreen> createState() => _VenueChatScreenState();
}

class _VenueChatScreenState extends State<VenueChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Ticking timer for 24h countdown & room state
  Timer? _countdownTimer;
  Timer? _particlesTicker;

  // Floating reactions list
  final List<_FloatingReaction> _reactions = [];
  final math.Random _random = math.Random();

  // Animation controller for live pulsing indicator
  late AnimationController _livePulseController;
  late Animation<double> _livePulseAnimation;

  // Unread / scroll tracking
  bool _showScrollToBottom = false;
  bool _showEmojiTray = false;
  bool _isReminderSet = false;

  // Quick prompt chips
  final List<String> _quickPrompts = [
    '👋 Selamlar!',
    '📍 Giriş kapısındayım',
    '🎸 Sahne önü harika!',
    '🍻 İçecek alanındayım',
    '🔥 Harika bir atmosfer!',
    '✨ Biriyle tanışmak isteyen?',
    '📸 Çok iyi bir gece!',
  ];

  // Quick reactions
  final List<String> _quickEmojis = ['❤️', '🔥', '🎉', '👏', '🍻', '⚡', '🎸', '💃'];

  @override
  void initState() {
    super.initState();

    // Pulse animation for live badge
    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _livePulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _livePulseController, curve: Curves.easeInOut),
    );

    // Scroll listener
    _scrollController.addListener(_onScroll);

    // Initial message load & reaction listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final service = context.read<MockEventService>();
        service.loadVenueMessages(widget.event.id);
        service.onVenueReactionReceived = (emoji) {
          if (mounted) {
            _spawnFloatingReaction(emoji);
          }
        };
      }
    });

    // 1-second ticker for countdown updates & room status
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Particles loop (60fps)
    _particlesTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted && _reactions.isNotEmpty) {
        final now = DateTime.now();
        setState(() {
          _reactions.removeWhere((r) => now.difference(r.createdAt).inMilliseconds > 2600);
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _particlesTicker?.cancel();
    _livePulseController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final isAwayFromBottom = (maxScroll - currentScroll) > 160;
    if (isAwayFromBottom != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isAwayFromBottom;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _spawnFloatingReaction(String emoji) {
    final reaction = _FloatingReaction(
      id: UniqueKey().toString(),
      emoji: emoji,
      startX: 0.65 + _random.nextDouble() * 0.28,
      speed: 0.8 + _random.nextDouble() * 0.5,
      wobbleSpeed: 2.0 + _random.nextDouble() * 3.0,
      wobbleAmount: 18.0 + _random.nextDouble() * 24.0,
      scale: 0.9 + _random.nextDouble() * 0.5,
      createdAt: DateTime.now(),
    );
    setState(() {
      _reactions.add(reaction);
    });
  }

  void _onReactionTapped(String emoji) {
    HapticFeedback.lightImpact();
    _spawnFloatingReaction(emoji);
    _spawnFloatingReaction(emoji);
    context.read<MockEventService>().sendVenueReaction(widget.event.id, emoji);
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    context.read<MockEventService>().sendVenueMessage(widget.event.id, text);
    if (customText == null) {
      _controller.clear();
    }

    Future.delayed(const Duration(milliseconds: 120), () {
      _scrollToBottom(animated: true);
    });
  }

  /// Dynamic distinct streamer color for usernames
  Color _getStreamerColor(String name) {
    final colors = [
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFFF2E93), // Neon Pink
      const Color(0xFFFFB800), // Gold / Amber
      const Color(0xFF10B981), // Emerald Green
      const Color(0xFFA855F7), // Neon Purple
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF38BDF8), // Sky Blue
      const Color(0xFFF43F5E), // Rose
      const Color(0xFF84CC16), // Lime
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Check 24-hour activation window
    final isRoomActive = widget.event.isRoomActive;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      body: Stack(
        children: [
          // 1. Ambient blurred background of event poster
          _buildBackgroundBackdrop(),

          // 2. Main content: Locked 24h Countdown OR Active Streamer Live Chat
          SafeArea(
            bottom: false,
            child: isRoomActive ? _buildStreamerChatView() : _buildLockedCountdownView(),
          ),

          // 3. Floating Live Reactions Particle Overlay (Over everything)
          if (isRoomActive) _buildFloatingReactionsOverlay(),
        ],
      ),
    );
  }

  // ==========================================
  // BACKGROUND BACKDROP
  // ==========================================
  Widget _buildBackgroundBackdrop() {
    return Positioned.fill(
      child: Stack(
        children: [
          if (widget.event.imageUrl.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: widget.event.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF08090E).withValues(alpha: 0.88),
                      const Color(0xFF0E1018).withValues(alpha: 0.94),
                      const Color(0xFF07080D).withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Subtle glowing ambient light spots
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. LOCKED COUNTDOWN VIEW (>24 HOURS)
  // ==========================================
  Widget _buildLockedCountdownView() {
    final timeUntil = widget.event.timeUntilRoomOpens;
    final days = timeUntil.inDays;
    final hours = timeUntil.inHours % 24;
    final minutes = timeUntil.inMinutes % 60;
    final seconds = timeUntil.inSeconds % 60;
    final formattedEventDate = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(widget.event.dateTime);

    return Column(
      children: [
        // App Bar
        _buildCountdownAppBar(),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Glowing Lock Avatar / Icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            const Color(0xFF7928CA),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF141622),
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        size: 46,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Title & Subtitle
                const Text(
                  'Mekan Sohbeti & Check-in',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 15, color: Colors.amberAccent),
                      SizedBox(width: 6),
                      Text(
                        'Etkinliğe 24 Saat Kala Açılır',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Digital Countdown Ticker Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCountdownBox('$days', 'GÜN'),
                    _buildCountdownSeparator(),
                    _buildCountdownBox(hours.toString().padLeft(2, '0'), 'SAAT'),
                    _buildCountdownSeparator(),
                    _buildCountdownBox(minutes.toString().padLeft(2, '0'), 'DAKİKA'),
                    _buildCountdownSeparator(),
                    _buildCountdownBox(seconds.toString().padLeft(2, '0'), 'SANİYE', isAccent: true),
                  ],
                ),

                const SizedBox(height: 32),

                // Event Preview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131622).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: widget.event.imageUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                color: AppColors.surface,
                                child: const Icon(Icons.event, color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 13, color: Colors.redAccent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        widget.event.location,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          Text(
                            formattedEventDate,
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFFA855F7)),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.event.attendees.isNotEmpty ? widget.event.attendees.length : 18} Katılımcı geri sayımda',
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF00E5FF), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Güvenli ve gerçek katılımcı deneyimi için, canlı mekan sohbeti ve check-in sistemi etkinlik saatine 24 saat kaldığında otomatik olarak aktifleşir.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Notification Reminder Toggle Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isReminderSet = !_isReminderSet;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isReminderSet
                                ? '🔔 Hatırlatıcı kuruldu! 24 saat kala bildirim alacaksın.'
                                : 'Hatırlatıcı iptal edildi.',
                          ),
                          backgroundColor: _isReminderSet ? AppColors.primary : Colors.grey[800],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    },
                    icon: Icon(
                      _isReminderSet ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      _isReminderSet ? 'HATIRLATICI KURULDU (24 SAAT KALA)' : '24 SAAT KALA BANA HABER VER',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReminderSet ? const Color(0xFF10B981) : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Etkinlik Canlı Odası 🔒',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(String value, String label, {bool isAccent = false}) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF161928).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAccent ? AppColors.primary : Colors.white.withValues(alpha: 0.12),
              width: isAccent ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isAccent ? AppColors.primary.withValues(alpha: 0.25) : Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            value,
            style: TextStyle(
              color: isAccent ? AppColors.primaryVariant : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.only(bottom: 18),
      child: const Text(
        ':',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // 2. ACTIVE STREAMER CHAT VIEW (<24 HOURS)
  // ==========================================
  Widget _buildStreamerChatView() {
    return Column(
      children: [
        // Top Streamer Header
        _buildStreamerHeader(),

        // Flowing Stream Chat Feed
        Expanded(
          child: Stack(
            children: [
              Consumer<MockEventService>(
                builder: (context, service, child) {
                  final messages = service.getVenueMessages(widget.event.id);
                  if (messages.isEmpty) {
                    return _buildEmptyStreamPlaceholder();
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = (msg['userId'] ?? '').toString().toLowerCase().trim() ==
                          service.currentUserId.toLowerCase().trim();
                      return _buildStreamerMessageRow(msg, isMe, index);
                    },
                  );
                },
              ),

              // Floating "Scroll To Bottom" Pill
              if (_showScrollToBottom)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _scrollToBottom(animated: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Yeni Mesajlar',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Quick Event Prompts Chips
        _buildQuickPromptsBar(),

        // Quick Floating Reactions Pill Bar
        _buildQuickReactionsPillBar(),

        // Bottom Input or Check-in Lock Action
        _buildStreamerBottomArea(),
      ],
    );
  }

  // Streamer Header with Live Pulse and Viewer Pill
  Widget _buildStreamerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F18).withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Pulsing Red Live Badge
                    AnimatedBuilder(
                      animation: _livePulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _livePulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2E56),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2E56).withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'CANLI CHAT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 11, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        widget.event.location,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Attendees Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group_rounded, size: 13, color: Color(0xFF00E5FF)),
                const SizedBox(width: 5),
                Text(
                  '${widget.event.attendees.isNotEmpty ? widget.event.attendees.length : 24} Canlı',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Streamer Message Row (Twitch / Kick / YouTube live chat style)
  Widget _buildStreamerMessageRow(Map<String, dynamic> msg, bool isMe, int index) {
    final senderName = msg['userName'] ?? (isMe ? 'Sen' : 'Katılımcı');
    final messageText = msg['message'] ?? '';
    final senderColor = _getStreamerColor(senderName);
    final timeStr = msg['time'] is DateTime
        ? DateFormat('HH:mm').format(msg['time'] as DateTime)
        : DateFormat('HH:mm').format(DateTime.now());

    // Role tags
    final isHost = index == 0 && !isMe;
    final isVip = (index % 3 == 0) && !isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.18)
              : const Color(0xFF141724).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User mini avatar with neon border
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [senderColor, senderColor.withValues(alpha: 0.4)],
                ),
                border: Border.all(color: senderColor, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges, Name and Time row
                  Row(
                    children: [
                      // Role badges
                      if (isHost)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6), width: 0.8),
                          ),
                          child: const Text(
                            '👑 EV SAHİBİ',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                        )
                      else if (isVip)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 0.8),
                          ),
                          child: const Text(
                            '🔥 VIP',
                            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                        )
                      else if (isMe)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 0.8),
                          ),
                          child: const Text(
                            '📍 MEKANDA',
                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                        ),

                      // Sender Name
                      Text(
                        isMe ? 'Sen' : senderName,
                        style: TextStyle(
                          color: senderColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Message Text
                  Text(
                    messageText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Empty state placeholder
  Widget _buildEmptyStreamPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.forum_outlined, size: 48, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Canlı Yayın Sohbeti Başladı! ⚡',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Mekandaki diğer katılımcılara ilk canlı mesajı sen gönder!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Quick prompt chips
  Widget _buildQuickPromptsBar() {
    return Consumer<MockEventService>(
      builder: (context, service, _) {
        final isCheckedIn = service.isUserCheckedIn(widget.event.id);
        if (!isCheckedIn) return const SizedBox.shrink();

        return Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _quickPrompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = _quickPrompts[index];
              return ActionChip(
                label: Text(
                  prompt,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xFF161928).withValues(alpha: 0.9),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: () => _sendMessage(prompt),
              );
            },
          ),
        );
      },
    );
  }

  // Quick Reactions Pill Bar
  Widget _buildQuickReactionsPillBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _quickEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => _onReactionTapped(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Bottom Input area OR Check-in Lock Action
  Widget _buildStreamerBottomArea() {
    return Consumer<MockEventService>(
      builder: (context, service, child) {
        final isCheckedIn = service.isUserCheckedIn(widget.event.id);

        if (!isCheckedIn) {
          // Check-in requirement banner
          return Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111420),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.amberAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mekanda mısın?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Canlı sohbete yazmak için check-in yap.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    service.checkIn(widget.event.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Check-in yapıldı! (+50 Puan) 🎉 Canlı sohbete yazabilirsin.'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                  label: const Text('CHECK-IN YAP', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 3,
                  ),
                ),
              ],
            ),
          );
        }

        // Active Glass Text Input Bar
        return Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F121E),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showEmojiTray) _buildEmojiTray(),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmojiTray ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                      color: _showEmojiTray ? const Color(0xFF00E5FF) : Colors.white60,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _showEmojiTray = !_showEmojiTray;
                      });
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181C2E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Mekandakilere canlı mesaj yaz...',
                          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, const Color(0xFF7928CA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmojiTray() {
    final emojis = ['😍', '🔥', '🥳', '😎', '💃', '🕺', '🥂', '🎉', '🎸', '🌟', '🤘', '❤️', '👏', '⚡', '💯', '✨'];
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          final e = emojis[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _controller.text = '${_controller.text}$e';
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. FLOATING REACTIONS PARTICLES LAYER
  // ==========================================
  Widget _buildFloatingReactionsOverlay() {
    final size = MediaQuery.of(context).size;
    final now = DateTime.now();

    return IgnorePointer(
      child: Stack(
        children: _reactions.map((r) {
          final elapsedMs = now.difference(r.createdAt).inMilliseconds;
          final progress = (elapsedMs / 2500.0).clamp(0.0, 1.0);

          // Fly upwards from bottom
          final startY = size.height - 130;
          final currentY = startY - (progress * (size.height * 0.55) * r.speed);

          // Wobble horizontally
          final wobble = math.sin(progress * math.pi * r.wobbleSpeed) * r.wobbleAmount;
          final currentX = (r.startX * size.width) + wobble;

          // Fade out near the end
          final opacity = progress < 0.6 ? 1.0 : (1.0 - (progress - 0.6) / 0.4).clamp(0.0, 1.0);
          // Scale grows slightly then shrinks
          final scale = (r.scale * (1.0 + math.sin(progress * math.pi) * 0.3)).clamp(0.4, 2.0);

          return Positioned(
            left: currentX,
            top: currentY,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  r.emoji,
                  style: const TextStyle(
                    fontSize: 28,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
