// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Y2K Palette ──────────────────────────────────────────────────────────────
const _bgTop        = Color(0xFFFCF4F9);
const _bgBottom     = Color(0xFFF0EAFF);
const _hotPink      = Color(0xFFFFB3D9);
const _neonPurple   = Color(0xFFD9B3FF);
const _accentPink   = Color(0xFFFF6FE8);
const _textPrimary  = Color(0xFF1A0D26);
const _textMuted    = Color(0xFF8A7EA5);
const _greenOnline  = Color(0xFF4ADE80);

// Bubble gradients
const _myBubbleStart  = Color(0xFFFFCCE6);
const _myBubbleEnd    = Color(0xFFFFB3D9);
const _theirBubbleClr = Colors.white;

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUsername;
  final String otherPhotoUrl;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherPhotoUrl,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatProvider>();
      chat.openChat(widget.chatId);
      chat.markMessagesRead(widget.otherUserId);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().closeChat();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    context.read<ChatProvider>().sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.05;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Consumer<ChatProvider>(
            builder: (context, chat, _) {
              return Column(
                children: [
                  _buildHeader(w, h),
                  _buildTasteBanner(w),
                  Expanded(child: _buildMessageList(chat)),
                  if (chat.replyingTo != null) _buildReplyPreview(chat, w),
                  _buildMessageInput(w, h),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double w, double h) {
    final avatarSize = (w * 0.1).clamp(36.0, 44.0);
    final titleFont = (w * 0.045).clamp(16.0, 18.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: _hotPink.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: widget.otherPhotoUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(widget.otherPhotoUrl), fit: BoxFit.cover)
                  : null,
              color: _neonPurple.withOpacity(0.2),
            ),
            child: widget.otherPhotoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          SizedBox(width: w * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUsername,
                  style: TextStyle(fontFamily: 'Circular', fontSize: titleFont, fontWeight: FontWeight.w900, color: _textPrimary),
                ),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _greenOnline, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text("Active now", style: TextStyle(fontFamily: 'Circular', fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _hotPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.graphic_eq_rounded, size: 14, color: _hotPink),
                SizedBox(width: 4),
                Text("Listening", style: TextStyle(fontFamily: 'Circular', fontSize: 10, fontWeight: FontWeight.w800, color: _hotPink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasteBanner(double w) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: 10),
      color: _neonPurple.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: _neonPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You both love Indie Pop & 80s Rock",
              style: TextStyle(fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w700, color: _textMuted.withOpacity(0.9)),
            ),
          ),
          const Text("94% Match", style: TextStyle(fontFamily: 'Circular', fontSize: 11, fontWeight: FontWeight.w900, color: _neonPurple)),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatProvider chat) {
    final messages = chat.messages;
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _hotPink.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text("Say hi! Music is a great icebreaker 🎵",
                style: TextStyle(fontFamily: 'Circular', color: _textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final isMe = msg.senderId == FirebaseAuth.instance.currentUser?.uid;
        return _ChatBubble(message: msg, isMe: isMe);
      },
    );
  }

  Widget _buildReplyPreview(ChatProvider chat, double w) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: 8),
      color: Colors.white.withOpacity(0.8),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: _hotPink, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chat.replyingTo?.text ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Circular', fontSize: 12, color: _textMuted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => chat.cancelReply(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(double w, double h) {
    final inputH = (h * 0.07).clamp(56.0, 72.0);

    return Container(
      padding: EdgeInsets.fromLTRB(w * 0.04, 12, w * 0.04, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _bgTop, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.music_note_rounded, color: _hotPink, size: 22),
          ),
          SizedBox(width: w * 0.03),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: _bgTop, borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontFamily: 'Circular', fontSize: 14, color: _textPrimary),
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(fontFamily: 'Circular', color: _textMuted, fontSize: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: w * 0.03),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_hotPink, _neonPurple]),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.replyToText != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.replyToText!,
                style: const TextStyle(fontFamily: 'Circular', fontSize: 11, color: _textMuted),
              ),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                CircleAvatar(radius: 12, backgroundColor: _neonPurple.withOpacity(0.3), child: const Icon(Icons.person, size: 14, color: Colors.white)),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe ? const LinearGradient(colors: [_myBubbleStart, _myBubbleEnd]) : null,
                    color: isMe ? null : _theirBubbleClr,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontFamily: 'Circular',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isMe ? Colors.white : _textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "12:45 PM",
                style: TextStyle(fontFamily: 'Circular', fontSize: 10, color: _textMuted.withOpacity(0.7), fontWeight: FontWeight.w600),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Icon(Icons.done_all_rounded, size: 14, color: _hotPink),
              ],
            ],
          ),
        ],
      ),
    );
  }
}