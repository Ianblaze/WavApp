import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime? timestamp;
  final String status;
  final String? replyToText;
  final String? replyToSenderId;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.timestamp,
    required this.status,
    this.replyToText,
    this.replyToSenderId,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      text: d['text'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
      status: d['status'] ?? 'sent',
      replyToText: d['replyTo'],
      replyToSenderId: d['replyToSender'],
    );
  }
}
