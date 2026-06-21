import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSession {
  ChatSession({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessagePreview,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessagePreview;

  factory ChatSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final DateTime now = DateTime.now().toUtc();

    return ChatSession(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate().toUtc() ?? now,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate().toUtc() ?? now,
      lastMessagePreview: data['lastMessagePreview'] as String? ?? '',
    );
  }
}
