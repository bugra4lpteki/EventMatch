import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/event_model.dart';
import '../services/mock_event_service.dart';

class VenueChatScreen extends StatefulWidget {
  final EventModel event;

  const VenueChatScreen({super.key, required this.event});

  @override
  State<VenueChatScreen> createState() => _VenueChatScreenState();
}

class _VenueChatScreenState extends State<VenueChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    context.read<MockEventService>().sendVenueMessage(
          widget.event.id,
          _controller.text.trim(),
        );
    _controller.clear();
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.event.title, style: const TextStyle(fontSize: 16)),
            Text('Mekan Sohbeti', style: TextStyle(fontSize: 12, color: AppColors.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sadece şu an mekanda olanlar mesaj atabilir.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MockEventService>(
              builder: (context, service, child) {
                final messages = service.getVenueMessages(widget.event.id);
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.surface),
                        const SizedBox(height: 16),
                        Text('Henüz kimse bir şey yazmadı.',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Text('Sohbeti başlatan ilk kişi sen ol!',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['userId'] == service.currentUser.id;
                    return _buildChatBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                msg['userName'],
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              msg['message'],
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: AppColors.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
