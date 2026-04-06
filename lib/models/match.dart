class Match {
  final String userId;
  final String username;
  final String photoUrl;
  final String status;
  final String decision;
  final String reason;
  final String assignedRole;
  final String? chatId;
  final String? docId;

  const Match({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.status,
    required this.decision,
    required this.reason,
    required this.assignedRole,
    this.chatId,
    this.docId,
  });
}
