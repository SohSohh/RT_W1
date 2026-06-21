import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isLoading = false,
    this.createdAt,
  });

  final ChatRole role;
  final String text;
  final bool isLoading;
  final DateTime? createdAt;

  Map<String, Object> toMap() {
    return <String, Object>{
      'role': role.name,
      'text': text,
      'createdAt': (createdAt ?? DateTime.now()).toUtc(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    final Object? rawRole = data['role'];
    final Object? rawText = data['text'];
    final Object? rawCreatedAt = data['createdAt'];

    return ChatMessage(
      role: rawRole == ChatRole.user.name ? ChatRole.user : ChatRole.assistant,
      text: rawText is String ? rawText : '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate().toUtc() : null,
    );
  }
}
