// chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ----------------------
// Y2K COLORS
// ----------------------
const bgTop = Color(0xFFFFE6FF);
const bgMid = Color(0xFFF3E5FF);
const bgBottom = Color(0xFFE1E9FF);

const y2kPink = Color(0xFFFF6FE8);
const y2kPurple = Color(0xFFB69CFF);
const mutedText = Color(0xFF8A7EA5);
const textDark = Color(0xFF3A2A45);

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
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgTop, bgMid, bgBottom],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(),
          body: Consumer<ChatProvider>(
            builder: (context, chat, _) {
              return Column(
                children: [
                  Expanded(child: _buildMessageList(chat)),
                  if (chat.replyingTo != null) _buildReplyPreview(chat),
                  _buildMessageInput(),
                ],
              );
            },
          ),
        )
      ],
    );
  }

  // ---------------------
  // APP BAR
  // ---------------------
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back_ios, color: textDark),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: widget.otherPhotoUrl.isNotEmpty
                ? NetworkImage(widget.otherPhotoUrl)
                : const AssetImage("assets/images/default_pfp.png")
                    as ImageProvider,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.otherUsername,
                  style: const TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const Text("Connected",
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  // ---------------------
  // MESSAGE LIST
  // ---------------------
  Widget _buildMessageList(ChatProvider chat) {
    final messages = chat.messages;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: y2kPink),
      );
    }

    // Messages from provider stream are ordered ascending; reverse for UI
    final reversed = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: reversed.length,
      reverse: true,
      addAutomaticKeepAlives: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final msg = reversed[index];
        final isMe = msg.senderId == currentUid;
        return _buildSwipeableMessage(msg, isMe, chat);
      },
    );
  }

  // ---------------------
  // SWIPEABLE MESSAGE
  // ---------------------
  Widget _buildSwipeableMessage(Message msg, bool isMe, ChatProvider chat) {
    return GestureDetector(
      onDoubleTap: () => chat.setReply(msg),
      child: Align(
        key: ValueKey(msg.id),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? y2kPink : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply preview if this message is a reply
              if (msg.replyToText != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withOpacity(0.25)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? Colors.white : y2kPink,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    msg.replyToText!,
                    style: TextStyle(
                      color:
                          isMe ? Colors.white70 : textDark.withOpacity(0.7),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Message text
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? Colors.white : textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 3),

              // Status and time row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : mutedText,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    _buildReadReceipt(msg.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------
  // READ RECEIPT ICONS
  // ---------------------
  Widget _buildReadReceipt(String status) {
    if (status == "read") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: Colors.blue[400]),
        ],
      );
    } else if (status == "delivered") {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: Colors.white70),
        ],
      );
    } else {
      return const Icon(Icons.done, size: 16, color: Colors.white70);
    }
  }

  // ---------------------
  // FORMAT TIME
  // ---------------------
  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return "";
    return "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
  }

  // ---------------------
  // REPLY PREVIEW BAR
  // ---------------------
  Widget _buildReplyPreview(ChatProvider chat) {
    final replyingTo = chat.replyingTo!;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyMessage = replyingTo.senderId == currentUid;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EBFF),
        border: Border(
          top: BorderSide(color: Colors.purple.withOpacity(0.15), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 35,
            decoration: BoxDecoration(
              color: y2kPink,
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
                  isMyMessage ? "You" : widget.otherUsername,
                  style: const TextStyle(
                    color: y2kPink,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyingTo.text,
                  style: const TextStyle(color: textDark, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => chat.cancelReply(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, color: mutedText, size: 20),
          ),
        ],
      ),
    );
  }

  // ---------------------
  // MESSAGE INPUT BAR
  // ---------------------
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input pill
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EBFF),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                maxLines: null,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Message...",
                  hintStyle: TextStyle(color: mutedText, fontSize: 15),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(color: textDark, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Image.asset(
              "assets/images/send.png",
              width: 46,
              height: 46,
            ),
          ),
        ],
      ),
    );
  }
}