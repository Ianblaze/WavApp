import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../pages/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<Message> _messages = [];
  bool _isSending = false;
  Message? _replyingTo;
  String? _activeChatId;
  StreamSubscription<QuerySnapshot>? _messageStream;

  List<Message> get messages => _messages;
  bool get isSending => _isSending;
  Message? get replyingTo => _replyingTo;

  Future<String> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    return await _chatService.createOrGetChat(otherUserId);
  }

  void openChat(String chatId) {
    _activeChatId = chatId;
    _messages = [];
    notifyListeners();
    _messageStream = _chatService.messagesStream(chatId).listen((snap) {
      _messages = snap.docs.map((d) => Message.fromDoc(d)).toList();
      notifyListeners();
    });
  }

  void closeChat() {
    _messageStream?.cancel();
    _messageStream = null;
    _activeChatId = null;
    _messages = [];
    _replyingTo = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_activeChatId == null || text.trim().isEmpty || _isSending) return;
    _isSending = true;
    final reply = _replyingTo;
    _replyingTo = null;
    notifyListeners();
    try {
      await _chatService.sendMessage(_activeChatId!, text, replyTo: reply);
    } catch (e) {
      debugPrint('sendMessage error: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void setReply(Message message) {
    _replyingTo = message;
    notifyListeners();
  }

  void cancelReply() {
    _replyingTo = null;
    notifyListeners();
  }

  Future<void> markMessagesRead(String otherUserId) async {
    if (_activeChatId == null) return;
    final msgs = await _chatService.unreadMessages(_activeChatId!, otherUserId);
    for (final id in msgs) {
      await _chatService.markMessageRead(_activeChatId!, id);
    }
  }

  @override
  void dispose() {
    _messageStream?.cancel();
    super.dispose();
  }
}
