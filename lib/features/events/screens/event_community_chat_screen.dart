import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/content_filter_service.dart';
import '../../../core/widgets/report_block_sheet.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/mock_event_service.dart';

class EventCommunityChatScreen extends StatefulWidget {
  final EventModel event;

  const EventCommunityChatScreen({super.key, required this.event});

  @override
  State<EventCommunityChatScreen> createState() => _EventCommunityChatScreenState();
}

class _CommunityMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isOrganizer;

  _CommunityMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.isOrganizer = false,
  });

  factory _CommunityMessage.fromMap(Map<String, dynamic> map) {
    return _CommunityMessage(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      senderId: map['sender_id']?.toString() ?? '',
      senderName: map['sender_name']?.toString() ?? 'Katılımcı',
      senderAvatar: map['sender_avatar']?.toString() ?? '',
      text: map['content']?.toString() ?? map['text']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      timestamp: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      isOrganizer: map['is_organizer'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': text,
      'image_url': imageUrl,
      'created_at': timestamp.toUtc().toIso8601String(),
      'is_organizer': isOrganizer,
    };
  }
}

class _EventCommunityChatScreenState extends State<EventCommunityChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _roomChannel;
  final List<_CommunityMessage> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _subscribeToRoom();
  }

  @override
  void dispose() {
    _roomChannel?.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _roomKey => 'event_community_${widget.event.id}';

  void _loadInitialMessages() {
    // Başlangıç karşılama mesajları ve örnek grup mesajları
    final now = DateTime.now();
    final sampleMessages = [
      _CommunityMessage(
        id: 'sys_welcome',
        senderId: 'system_bot',
        senderName: 'EventMatch Bot 🤖',
        senderAvatar: '',
        text: '🎉 ${widget.event.title} Topluluk Grubuna Hoş Geldiniz! Burada diğer katılımcılarla tanışabilir, bilet ve ulaşım planı yapabilirsiniz.',
        timestamp: now.subtract(const Duration(hours: 4)),
        isOrganizer: true,
      ),
      if (widget.event.attendees.isNotEmpty)
        _CommunityMessage(
          id: 'msg_welcome_1',
          senderId: widget.event.attendees.first.id,
          senderName: widget.event.attendees.first.name,
          senderAvatar: widget.event.attendees.first.avatarUrl,
          text: 'Selam herkese! Konsere kimler Kadıköy tarafından geliyor? Beraber geçebiliriz 🎸',
          timestamp: now.subtract(const Duration(hours: 2)),
        ),
      if (widget.event.attendees.length > 1)
        _CommunityMessage(
          id: 'msg_welcome_2',
          senderId: widget.event.attendees[1].id,
          senderName: widget.event.attendees[1].name,
          senderAvatar: widget.event.attendees[1].avatarUrl,
          text: 'Ben de oradayım! Konser öncesi kahve içip tanışalım diyen var mı? ☕',
          timestamp: now.subtract(const Duration(minutes: 45)),
        ),
    ];

    setState(() {
      _messages.addAll(sampleMessages);
      _isLoading = false;
    });
  }

  void _subscribeToRoom() {
    try {
      _roomChannel = _supabase.channel(_roomKey);
      _roomChannel?.onBroadcast(
        event: 'new_community_message',
        callback: (payload) {
          if (!mounted) return;
          final msg = _CommunityMessage.fromMap(payload);
          final eventService = context.read<MockEventService>();
          if (msg.senderId != eventService.currentUserId) {
            setState(() {
              _messages.add(msg);
            });
            _scrollToBottom();
          }
        },
      ).subscribe();
    } catch (e) {
      debugPrint('[CommunityChat] Kanal abonelik hatası: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty && imageUrl == null) return;

    final censoredText = ContentFilterService.instance.censorText(rawText);
    final eventService = context.read<MockEventService>();
    final me = eventService.currentUser;

    final newMsg = _CommunityMessage(
      id: 'comm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: eventService.currentUserId,
      senderName: me.name,
      senderAvatar: me.avatarUrl,
      text: censoredText,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
      isOrganizer: widget.event.creatorId == eventService.currentUserId,
    );

    setState(() {
      _messages.add(newMsg);
      _textController.clear();
    });

    HapticFeedback.lightImpact();
    _scrollToBottom();

    // Realtime broadcast ile gruptaki herkese yay
    _roomChannel?.sendBroadcastMessage(
      event: 'new_community_message',
      payload: newMsg.toMap(),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final ext = pickedFile.name.split('.').last.toLowerCase();
      final fileName = 'comm_${DateTime.now().millisecondsSinceEpoch}.$ext';

      String bucket = 'chat-media';
      try {
        await _supabase.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
      } catch (_) {
        bucket = 'avatars';
        await _supabase.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
      }

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);
      setState(() => _isUploading = false);
      _sendMessage(imageUrl: publicUrl);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenemedi: $e')),
        );
      }
    }
  }

  void _showGroupDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: widget.event.imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Colors.white12),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 4),
                          Text(
                            '${widget.event.attendees.length} Katılımcı • ${widget.event.location}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Etkinlik Katılımcıları',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.event.attendees.length,
                  itemBuilder: (context, index) {
                    final u = widget.event.attendees[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      leading: UserAvatar(user: u, radius: 22),
                      title: Text(u.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(u.city ?? 'Türkiye', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = context.watch<MockEventService>();
    final currentUid = eventService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        elevation: 1,
        titleSpacing: 0,
        leading: BackButton(color: AppColors.primary),
        title: InkWell(
          onTap: _showGroupDetails,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: widget.event.imageUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.white12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.event.attendees.length} Katılımcı Topluluk Grubu',
                        style: TextStyle(color: AppColors.primaryVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
            tooltip: 'Grup Bilgisi',
            onPressed: _showGroupDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner reminder for safe community
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white.withValues(alpha: 0.03),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saygılı ve güvenli bir topluluk için uygunsuz mesajları basılı tutarak şikayet edebilirsiniz.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == currentUid;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black26,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Fotoğraf yükleniyor...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_CommunityMessage msg, bool isMe) {
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        ReportBlockSheet.showOptionsModal(
          context,
          userId: msg.senderId,
          userName: msg.senderName,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              UserAvatar(
                user: UserModel(id: msg.senderId, name: msg.senderName, avatarUrl: msg.senderAvatar),
                radius: 16,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? AppColors.primaryGradient
                      : LinearGradient(
                          colors: [
                            const Color(0xFF1E202E),
                            const Color(0xFF181926),
                          ],
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            msg.senderName,
                            style: TextStyle(
                              color: AppColors.primaryVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (msg.isOrganizer) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Organizatör',
                                style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    if (!isMe) const SizedBox(height: 4),

                    if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: msg.imageUrl!,
                          width: 220,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(height: 140, color: Colors.white10),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    Text(
                      msg.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_camera_rounded, color: Colors.cyanAccent),
            tooltip: 'Fotoğraf Gönder',
            onPressed: _pickImage,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Topluluğa bir mesaj yaz...',
                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13.5),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
