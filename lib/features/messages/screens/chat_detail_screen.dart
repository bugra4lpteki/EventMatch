import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/report_block_sheet.dart';
import '../models/message_model.dart';
import '../services/mock_message_service.dart';
import '../../events/services/mock_event_service.dart';
import '../../events/services/mock_match_service.dart';
import '../../profile/screens/user_profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final Stream<List<MessageModel>> _messageStream;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _liveSyncTimer;
  Timer? _typingDebounceTimer;
  int _lastMessageCount = 0;

  // Alıntı (Swipe-to-Reply) durumu
  MessageModel? _replyingToMessage;

  // Sesli Mesaj (Voice Note) durumu
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.chat.messages.length;

    // Aktif sohbet ID'sini bildir (Bu sohbet açıkken bildirim sesi/penceresi bastırılır)
    NotificationService().activeChatId = widget.chat.participant.id;

    final msgService = context.read<MockMessageService>();
    _messageStream = msgService.getMessagesStream(widget.chat.participant.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
      msgService.markAsRead(widget.chat.id, partnerId: widget.chat.participant.id);
      msgService.syncChatMessagesForPartner(widget.chat.participant.id);
    });

    // 4 saniyelik canlı senkronizasyon emniyet sübabı
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        context.read<MockMessageService>().syncChatMessagesForPartner(widget.chat.participant.id);
      }
    });

    // Canlı "Yazıyor..." dinleyicisi ve gecikmeli durdurucu
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final msgService = context.read<MockMessageService>();
    final text = _messageController.text;
    if (text.isNotEmpty) {
      msgService.sendTypingStatus(widget.chat.participant.id, true);
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          msgService.sendTypingStatus(widget.chat.participant.id, false);
        }
      });
    } else {
      msgService.sendTypingStatus(widget.chat.participant.id, false);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    NotificationService().activeChatId = null;
    _liveSyncTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    });
  }

  void _sendMessage(MockMessageService msgService, String currentChatId, bool isBlocked) {
    if (isBlocked) return;

    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      final replyCopy = _replyingToMessage;
      _messageController.clear();
      setState(() => _replyingToMessage = null);

      msgService.sendMessage(
        currentChatId,
        text,
        receiverUserId: widget.chat.participant.id,
        replyToMessage: replyCopy,
      );

      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollToBottom(animated: true);
      });
    }
  }

  // --- FOTOĞRAF SEÇME VE GÖNDERME MOTORU ---
  Future<void> _showImagePickerSheet(MockMessageService msgService, String currentChatId) async {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: const Text('Fotoğraf Çek (Kamera)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Kameran ile anlık fotoğraf çek ve gönder', style: TextStyle(color: Colors.white60, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
                if (xFile != null) {
                  final replyCopy = _replyingToMessage;
                  setState(() => _replyingToMessage = null);
                  await msgService.sendImageMessage(
                    currentChatId,
                    widget.chat.participant.id,
                    xFile.path,
                    replyToMessage: replyCopy,
                  );
                  _scrollToBottom(animated: true);
                }
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: Colors.pinkAccent),
              ),
              title: const Text('Galeriden Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Galerindeki fotoğraflardan birini seç', style: TextStyle(color: Colors.white60, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                if (xFile != null) {
                  final replyCopy = _replyingToMessage;
                  setState(() => _replyingToMessage = null);
                  await msgService.sendImageMessage(
                    currentChatId,
                    widget.chat.participant.id,
                    xFile.path,
                    replyToMessage: replyCopy,
                  );
                  _scrollToBottom(animated: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: imageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
                    )
                  : Image.file(File(imageUrl), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // --- SES KAYDI (VOICE NOTE) MOTORU ---
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentRecordingPath = path;

        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        HapticFeedback.mediumImpact();

        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordSeconds++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesli mesaj için mikrofon izni gereklidir.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopAndSendRecording(MockMessageService msgService, String currentChatId) async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      final duration = _recordSeconds;

      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });

      if (path != null && duration >= 1) {
        HapticFeedback.lightImpact();
        final replyCopy = _replyingToMessage;
        setState(() => _replyingToMessage = null);

        await msgService.sendVoiceNote(
          currentChatId,
          widget.chat.participant.id,
          path,
          duration,
          replyToMessage: replyCopy,
        );

        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom(animated: true);
        });
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordTimer?.cancel();
      await _audioRecorder.stop();
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (await f.exists()) {
          await f.delete();
        }
      }
      HapticFeedback.lightImpact();
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    } catch (e) {
      debugPrint('Cancel recording error: $e');
    }
  }

  // --- EMOJİ REAKSİYON VE HIZLI YANIT MENÜSÜ ---
  void _showReactionSheet(BuildContext context, MessageModel message, MockMessageService service, String chatId) {
    HapticFeedback.mediumImpact();
    const emojis = ['❤️', '😂', '👏', '😮', '🔥', '👍'];
    final myId = service.currentUserId;
    final currentReaction = message.myReaction(myId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis.map((emoji) {
                final isSelected = currentReaction == emoji;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    service.toggleReaction(chatId, message.id, widget.chat.participant.id, emoji);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10),
            ListTile(
              dense: true,
              leading: const Icon(Icons.reply_rounded, color: Colors.white70),
              title: const Text('Bu Mesajı Yanıtla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _replyingToMessage = message;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEndMatchConfirmDialog(BuildContext context, MockMessageService service, String currentChatId, String partnerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eşleşmeyi Bitir', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '${widget.chat.participant.name} ile eşleşmeyi bitirmek ve sohbeti silmek istediğinizden emin misiniz? İleride birbirinizi tekrar keşfedip eşleşebilirsiniz.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final matchService = context.read<MockMatchService>();
              final nav = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await service.endMatchAndRemoveChat(currentChatId, partnerId);
              if (mounted) {
                matchService.unmarkSeenUser(partnerId);
                nav.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('${widget.chat.participant.name} ile eşleşme sonlandırıldı.')),
                );
              }
            },
            child: const Text('Eşleşmeyi Bitir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgService = context.watch<MockMessageService>();
    final isBlocked = msgService.isBlocked(widget.chat.participant.id);

    final currentChat = msgService.individualChats.firstWhere(
      (c) =>
          c.id == widget.chat.id ||
          c.participant.id.toLowerCase() == widget.chat.participant.id.toLowerCase(),
      orElse: () => widget.chat,
    );

    final currentUserObj = context.read<MockEventService>().currentUser;
    final myTags = currentUserObj.tags;
    final theirTags = currentChat.participant.tags;
    final commonTags = myTags.where((tag) => theirTags.contains(tag)).toList();

    String? matchInsightTitle;
    if (commonTags.isNotEmpty) {
      matchInsightTitle = "İkiniz de ${commonTags.take(3).join(', ')} seviyorsunuz!";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        elevation: 1,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(user: currentChat.participant),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage: currentChat.participant.avatarUrl.startsWith('http')
                    ? NetworkImage(currentChat.participant.avatarUrl)
                    : null,
                child: !currentChat.participant.avatarUrl.startsWith('http')
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            currentChat.participant.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary,
                              decoration: isBlocked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primary),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        final isTyping = msgService.isPartnerTyping(currentChat.participant.id);
                        if (isTyping && !isBlocked) {
                          return Row(
                            children: [
                              Text(
                                'Yazıyor',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const _PulsingDots(),
                            ],
                          );
                        }

                        final isOnline = msgService.isUserOnline(currentChat.participant.id) || currentChat.isOnline;
                        if (isOnline && !isBlocked) {
                          return Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Çevrimiçi',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }
                        return Text(
                          'Profili Gör',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: currentChat.participant),
                  ),
                );
              } else if (value == 'block') {
                ReportBlockSheet.showBlockConfirmationDialog(
                  context,
                  userId: currentChat.participant.id,
                  userName: currentChat.participant.name,
                  onUserBlocked: () {
                    msgService.toggleBlockUser(currentChat.participant.id);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              } else if (value == 'report') {
                ReportBlockSheet.showReportDialog(
                  context,
                  userId: currentChat.participant.id,
                  userName: currentChat.participant.name,
                  onUserBlocked: () {
                    msgService.toggleBlockUser(currentChat.participant.id);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              } else if (value == 'end_match') {
                _showEndMatchConfirmDialog(context, msgService, currentChat.id, currentChat.participant.id);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Profili Görüntüle', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isBlocked ? 'Engeli Kaldır' : 'Kullanıcıyı Engelle',
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.amber, size: 20),
                    SizedBox(width: 12),
                    Text('Şikayet Et', style: TextStyle(color: Colors.amber)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'end_match',
                child: Row(
                  children: [
                    Icon(Icons.heart_broken_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Eşleşmeyi Bitir', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isBlocked)
            Container(
              color: Colors.redAccent.withValues(alpha: 0.2),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bu kullanıcıyı engellediniz.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => msgService.toggleBlockUser(currentChat.participant.id),
                    child: const Text('Engeli Kaldır', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          if (matchInsightTitle != null && !isBlocked)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      matchInsightTitle,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          
          // DOĞRUDAN STREAMBUILDER İLE CANLI MESAJ LİSTESİ
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        'STREAM HATA: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }

                final streamList = snapshot.data ?? [];
                final fallbackList = currentChat.messages;
                final messages = streamList.length >= fallbackList.length ? (streamList.isNotEmpty ? streamList : fallbackList) : fallbackList;

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom(animated: true);
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.surface),
                        const SizedBox(height: 12),
                        Text(
                          'Eşleşme sağlandı! 🎉',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İlk mesajı göndererek sohbete başla.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final currentId = msgService.currentUserId.toLowerCase().trim();
                    final senderId = message.senderId.toLowerCase().trim();
                    final isMe = senderId == currentId ||
                        senderId == 'me' ||
                        (currentId.isEmpty && senderId != currentChat.participant.id.toLowerCase().trim());

                    final showDateHeader = index == 0 || !_isSameDay(messages[index].timestamp, messages[index - 1].timestamp);
                    final bubble = _buildSwipeableMessage(message, isMe, msgService, currentChat.id);

                    if (showDateHeader) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDateBadge(_formatDateHeader(message.timestamp)),
                          bubble,
                        ],
                      );
                    }
                    return bubble;
                  },
                );
              },
            ),
          ),

          // Alıntı Yapılan Mesaj Önizleme Barı (Swipe-to-Reply)
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2235),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyingToMessage!.senderId.toLowerCase().trim() == msgService.currentUserId.toLowerCase().trim()
                              ? 'Kendine yanıt veriyorsun'
                              : '${widget.chat.participant.name} yanıtlanıyor',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!.isAudio
                              ? '🎤 Sesli Mesaj'
                              : (_replyingToMessage!.isImage ? '📷 Fotoğraf' : _replyingToMessage!.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),

          _buildMessageComposer(msgService, currentChat.id, isBlocked),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Bugün';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Dün';
    } else if (date.year == now.year) {
      return DateFormat('d MMMM', 'tr_TR').format(date);
    } else {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    }
  }

  Widget _buildDateBadge(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Sağa Kaydırarak Yanıtlama (Swipe-to-Reply) ve Uzun Basarak Reaksiyon Menüsü
  Widget _buildSwipeableMessage(
    MessageModel message,
    bool isMe,
    MockMessageService msgService,
    String currentChatId,
  ) {
    return Dismissible(
      key: ValueKey('msg_${message.id}_${message.timestamp.millisecondsSinceEpoch}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        setState(() {
          _replyingToMessage = message;
        });
        return false; // Mesajı silme, sadece yanıtlamayı aktifleştir
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.reply_rounded, color: Colors.white, size: 20),
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showReactionSheet(context, message, msgService, currentChatId),
        child: _buildWhatsAppMessageBubble(message, isMe, msgService, currentChatId),
      ),
    );
  }

  Widget _buildReplySnippet(MessageModel message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : AppColors.primary,
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.replyToSenderName ?? 'Yanıt',
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            message.replyToText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBadges(MessageModel message, MockMessageService msgService, String currentChatId) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: message.reactionCounts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          final hasMine = message.myReaction(msgService.currentUserId) == emoji;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              msgService.toggleReaction(
                currentChatId,
                message.id,
                widget.chat.participant.id,
                emoji,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: hasMine
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasMine ? AppColors.primary : Colors.white12,
                  width: 1,
                ),
              ),
              child: Text(
                count > 1 ? '$emoji $count' : emoji,
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// WhatsApp Tarzı Sade, Zarif ve Kompakt Mesaj Balonu
  Widget _buildWhatsAppMessageBubble(
    MessageModel message,
    bool isMe,
    MockMessageService msgService,
    String currentChatId,
  ) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    // 1. FOTOĞRAF MESAJI
    if (message.isImage && message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF6D28D9) : const Color(0xFF1F2232),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyToText != null && message.replyToText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: _buildReplySnippet(message, isMe),
                ),
              GestureDetector(
                onTap: () => _openFullScreenImage(context, message.mediaUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      message.mediaUrl!.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: message.mediaUrl!,
                              width: 240,
                              height: 240,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 240,
                                height: 240,
                                color: const Color(0xFF1E2235),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (context, url, error) {
                                final f = File(message.mediaUrl!);
                                if (f.existsSync()) {
                                  return Image.file(f, width: 240, height: 240, fit: BoxFit.cover);
                                }
                                return Container(
                                  width: 240,
                                  height: 240,
                                  color: const Color(0xFF1E2235),
                                  child: const Icon(Icons.broken_image_rounded, color: Colors.white60),
                                );
                              },
                            )
                          : Image.file(File(message.mediaUrl!), width: 240, height: 240, fit: BoxFit.cover),
                      Positioned(
                        bottom: 6,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(timeStr, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                _buildStatusTick(message.status),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.text.isNotEmpty && message.text != '📷 Fotoğraf')
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              if (message.reactionCounts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: _buildReactionBadges(message, msgService, currentChatId),
                ),
            ],
          ),
        ),
      );
    }

    // 2. SESLİ MESAJ
    if (message.isAudio) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF6D28D9) : const Color(0xFF1F2232),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyToText != null && message.replyToText!.isNotEmpty)
                _buildReplySnippet(message, isMe),
              VoiceMessageBubble(message: message, isMe: isMe),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusTick(message.status),
                    ],
                  ],
                ),
              ),
              if (message.reactionCounts.isNotEmpty)
                _buildReactionBadges(message, msgService, currentChatId),
            ],
          ),
        ),
      );
    }

    // 3. NORMAL METİN MESAJI: WRAP İLE İÇERİK KADAR KÜÇÜLEN ZARİF BALON
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6D28D9) : const Color(0xFF1F2232),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToText != null && message.replyToText!.isNotEmpty)
              _buildReplySnippet(message, isMe),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.white60,
                        fontSize: 10.5,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusTick(message.status),
                    ],
                  ],
                ),
              ],
            ),
            if (message.reactionCounts.isNotEmpty)
              _buildReactionBadges(message, msgService, currentChatId),
          ],
        ),
      ),
    );
  }

  /// WhatsApp & Telegram Tık İkonları:
  /// Saat ikonu (Gönderiliyor) -> Tek gri tık (Gönderildi) -> Çift gri tık (İletildi) -> Çift mavi tık (Okundu)
  Widget _buildStatusTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 12, color: Colors.white60);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF34B7F1));
    }
  }

  Widget _buildMessageComposer(MockMessageService msgService, String currentChatId, bool isBlocked) {
    // Ses Kaydediliyor Ekranı
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10).copyWith(
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF171923),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_recordSeconds ~/ 60)}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Ses kaydediliyor...',
                style: TextStyle(color: Colors.white60, fontSize: 13.5),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white60, size: 24),
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _stopAndSendRecording(msgService, currentChatId),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    // Normal Metin, Fotoğraf Ekleme & Mikrofon Giriş Alanı
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF171923),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Fotoğraf Ekleme Düğmesi (Kamera & Galeri)
          GestureDetector(
            onTap: isBlocked ? null : () => _showImagePickerSheet(msgService, currentChatId),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isBlocked ? Colors.transparent : const Color(0xFF1E2235),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: isBlocked ? Colors.white24 : AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !isBlocked,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: isBlocked ? AppColors.textSecondary : AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: isBlocked ? '🚫 Kullanıcı engellendi' : 'Mesaj yaz...',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
                filled: true,
                fillColor: const Color(0xFF0D0E15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(msgService, currentChatId, isBlocked),
            ),
          ),
          const SizedBox(width: 8),

          // Metin varsa Gönder Butonu, yoksa Ses Kaydetme Mikrofonu
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              if (hasText) {
                return GestureDetector(
                  onTap: isBlocked ? null : () => _sendMessage(msgService, currentChatId, isBlocked),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isBlocked ? null : AppColors.primaryGradient,
                      color: isBlocked ? Colors.grey : null,
                      shape: BoxShape.circle,
                      boxShadow: isBlocked
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                );
              }

              // Mikrofon butonu (Sesli Mesaj)
              return GestureDetector(
                onTap: isBlocked ? null : _startRecording,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.grey : const Color(0xFF1E2235),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Sesli Mesaj Oynatıcı Bileşeni (Voice Note Bubble)
class VoiceMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const VoiceMessageBubble({super.key, required this.message, required this.isMe});

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = Duration(seconds: widget.message.audioDurationSeconds ?? 0);

    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted && d.inSeconds > 0) setState(() => _duration = d);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;

    HapticFeedback.selectionClick();
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _player.play(UrlSource(url));
      } else {
        await _player.play(DeviceFileSource(url));
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    const barHeights = [10, 16, 22, 12, 18, 26, 16, 12, 24, 20, 14, 12, 18, 24, 14, 8];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white.withValues(alpha: 0.25) : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(barHeights.length, (i) {
                    final barProgress = i / barHeights.length;
                    final isFilled = barProgress <= progress;
                    return Container(
                      width: 3,
                      height: barHeights[i].toDouble(),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isFilled
                            ? (widget.isMe ? Colors.white : AppColors.primary)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying ? _formatDuration(_position) : _formatDuration(_duration),
                  style: TextStyle(
                    color: widget.isMe ? Colors.white70 : Colors.white60,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Canlı "Yazıyor..." 3 Nokta Animasyonu
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final val = ((_controller.value - delay) % 1.0);
            final scale = 0.4 + (0.6 * (val < 0.5 ? val * 2 : (1.0 - val) * 2));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 4.5,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: scale.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
