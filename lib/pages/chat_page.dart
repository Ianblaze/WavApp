// chat_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  bool _sending = false;
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream() {
    return FirebaseFirestore.instance
        .collection("chats")
        .doc(widget.chatId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // Mark messages as read when user opens chat
  Future<void> _markMessagesAsRead() async {
    final messages = await FirebaseFirestore.instance
        .collection("chats")
        .doc(widget.chatId)
        .collection("messages")
        .where("senderId", isEqualTo: widget.otherUserId)
        .where("status", isNotEqualTo: "read")
        .get();

    for (var doc in messages.docs) {
      doc.reference.update({"status": "read"});
    }
  }

  // ------------------------
  // SEND MESSAGE
  // ------------------------
  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _sending = true;

    // Capture reply data before clearing (don't use setState yet)
    Map<String, dynamic>? replyData;
    if (_replyingTo != null) {
      replyData = {
        "replyTo": _replyingTo!["text"],
        "replyToSender": _replyingTo!["senderId"],
      };
      _replyingTo = null; // Clear without setState
    }

    _messageController.clear();

    try {
      final messageData = <String, dynamic>{
        "senderId": FirebaseAuth.instance.currentUser!.uid,
        "text": text,
        "timestamp": Timestamp.now(),
        "status": "sent",
      };

      // Add reply info if it exists
      if (replyData != null) {
        messageData.addAll(replyData);
      }

      await FirebaseFirestore.instance
          .collection("chats")
          .doc(widget.chatId)
          .collection("messages")
          .add(messageData);
    } catch (e) {
      debugPrint("send message error: $e");
    }

    _sending = false;
    
    // Update UI only once at the end if reply bar was showing
    if (replyData != null && mounted) {
      setState(() {});
    }
  }

  // ------------------------
  // REPLY TO MESSAGE
  // ------------------------
  void _replyToMessage(Map<String, dynamic> msg) {
    setState(() {
      _replyingTo = msg;
    });
  }

  // ------------------------
  // CANCEL REPLY
  // ------------------------
  void _cancelReply() {
    setState(() => _replyingTo = null);
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
          body: Column(
            children: [
              Expanded(child: _buildMessageList()),
              if (_replyingTo != null) _buildReplyPreview(),
              _buildMessageInput(),
            ],
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
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: y2kPink));
        }

        final messages = snapshot.data?.docs ?? [];

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          reverse: true,
          addAutomaticKeepAlives: true,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final doc = messages[index];
            final msg = doc.data();
            final msgId = doc.id;
            final isMe =
                msg["senderId"] == FirebaseAuth.instance.currentUser!.uid;

            return _buildSwipeableMessage(msg, msgId, isMe);
          },
        );
      },
    );
  }

  // ---------------------
  // SWIPEABLE MESSAGE
  // ---------------------
  Widget _buildSwipeableMessage(
      Map<String, dynamic> msg, String msgId, bool isMe) {
    return GestureDetector(
      onDoubleTap: () => _replyToMessage(msg),
      child: Align(
        key: ValueKey(msgId),
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
              if (msg["replyTo"] != null) ...[
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
                    msg["replyTo"],
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
                msg["text"] ?? "",
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
                    _formatTime(msg["timestamp"]),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : mutedText,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    _buildReadReceipt(msg["status"] ?? "sent"),
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
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  // ---------------------
  // REPLY PREVIEW BAR
  // ---------------------
  Widget _buildReplyPreview() {
    final isMyMessage =
        _replyingTo!["senderId"] == FirebaseAuth.instance.currentUser!.uid;

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
                  _replyingTo!["text"],
                  style: const TextStyle(color: textDark, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
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
                onSubmitted: (_) {
                  _sendMessage();
                },
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