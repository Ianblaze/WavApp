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

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream() {
    return FirebaseFirestore.instance
        .collection("chats")
        .doc(widget.chatId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // ------------------------
  // AUTO SCROLL (Fixed)
  // ------------------------
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // ------------------------
  // SEND MESSAGE
  // ------------------------
  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _sending = true;
    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(widget.chatId)
          .collection("messages")
          .add({
        "senderId": FirebaseAuth.instance.currentUser!.uid,
        "text": text,
        "timestamp": Timestamp.now(), // Client-side timestamp to prevent double-update
      });

    } catch (e) {
      debugPrint("send message error: $e");
    }

    _sending = false;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: messages.length,
          reverse: true,
          addAutomaticKeepAlives: true,
          itemBuilder: (context, index) {
            final msg = messages[index].data();
            final msgId = messages[index].id;
            final isMe =
                msg["senderId"] == FirebaseAuth.instance.currentUser!.uid;

            return Align(
              key: ValueKey(msgId), // Prevents rebuilds
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                decoration: BoxDecoration(
                  color: isMe ? y2kPink : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(4),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),

                child: Text(
                  msg["text"] ?? "",
                  style: TextStyle(
                    color: isMe ? Colors.white : textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------
  // MESSAGE INPUT BAR
  // ---------------------
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Text input pill
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EBFF),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,

                // ENTER sends the message without button animation
                onSubmitted: (_) {
                  _sendMessage();
                },

                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: mutedText),
                ),
                style: const TextStyle(color: textDark, fontSize: 16),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Send button - simple tap, no animation states
          GestureDetector(
            onTap: _sendMessage,
            child: Image.asset(
              "assets/images/send.png",
              width: 52,
              height: 52,
            ),
          ),
        ],
      ),
    );
  }
}