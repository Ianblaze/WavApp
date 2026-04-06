// chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Deterministic chatId for two users -> sorted uids joined by underscore
  String chatIdFor(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Create chat document if not exists and return chatId
  Future<String> createOrGetChat(String otherUid) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) throw Exception('Not signed in');

    final chatId = chatIdFor(me, otherUid);
    final ref = _db.collection('chats').doc(chatId);

    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [me, otherUid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return chatId;
  }

  /// Send a message (adds to messages subcollection and updates chat doc)
  Future<void> sendMessage(String chatId, String text, {Message? replyTo}) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) throw Exception('Not signed in');
    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    final batch = _db.batch();

    final data = <String, dynamic>{
      'senderId': me,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'readBy': [me],
    };
    if (replyTo != null) {
      data['replyTo'] = replyTo.text;
      data['replyToSender'] = replyTo.senderId;
    }
    batch.set(msgRef, data);

    batch.update(chatRef, {
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Mark message read (adds uid to readBy on message doc)
  Future<void> markMessageRead(String chatId, String messageId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await msgRef.update({
      'readBy': FieldValue.arrayUnion([me]),
    });
  }

  /// Stream messages for chatId
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Stream chat doc (for lastMessage / meta)
  Stream<DocumentSnapshot<Map<String, dynamic>>> chatDocStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  /// Get unread messages from other user
  Future<List<String>> unreadMessages(String chatId, String otherUserId) async {
    final snap = await _db
        .collection('chats').doc(chatId).collection('messages')
        .where('senderId', isEqualTo: otherUserId)
        .where('status', isNotEqualTo: 'read')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }
}
