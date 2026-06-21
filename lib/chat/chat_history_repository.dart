import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_message.dart';
import 'chat_session.dart';

class ChatHistoryRepository {
  ChatHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sessions(String uid) {
    return _firestore.collection('users').doc(uid).collection('chat_sessions');
  }

  CollectionReference<Map<String, dynamic>> _messages(String uid, String sessionId) {
    return _sessions(uid).doc(sessionId).collection('messages');
  }

  Future<ChatSession> getOrCreateLatestSession(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _sessions(uid).get();

    if (snapshot.docs.isNotEmpty) {
      final List<DocumentSnapshot<Map<String, dynamic>>> docs = snapshot.docs.toList();
      docs.sort((DocumentSnapshot<Map<String, dynamic>> a, DocumentSnapshot<Map<String, dynamic>> b) {
        final DateTime aDate = ChatSession.fromDoc(a).updatedAt;
        final DateTime bDate = ChatSession.fromDoc(b).updatedAt;
        return bDate.compareTo(aDate);
      });
      return ChatSession.fromDoc(docs.first);
    }

    return createSession(uid);
  }

  Stream<List<ChatSession>> watchSessions(String uid) {
    return _sessions(uid).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<ChatSession> sessions = snapshot.docs.map(ChatSession.fromDoc).toList(growable: false);
        sessions.sort((ChatSession a, ChatSession b) => b.updatedAt.compareTo(a.updatedAt));
        return sessions;
      },
    );
  }

  Future<ChatSession> createSession(String uid) async {
    final DateTime now = DateTime.now().toUtc();
    final DocumentReference<Map<String, dynamic>> doc = _sessions(uid).doc();

    await doc.set(<String, Object>{
      'createdAt': now,
      'updatedAt': now,
      'lastMessagePreview': 'New chat',
    });

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await doc.get();
    return ChatSession.fromDoc(snapshot);
  }

  Stream<List<ChatMessage>> watchMessages(String uid, String sessionId) {
    return _messages(uid, sessionId)
        .orderBy('createdAt')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            return ChatMessage.fromMap(doc.data());
          })
          .toList(growable: false);
    });
  }

  Future<void> addMessage(String uid, String sessionId, ChatMessage message) async {
    final DateTime now = DateTime.now().toUtc();
    final DocumentReference<Map<String, dynamic>> messageDoc = _messages(uid, sessionId).doc();

    await messageDoc.set(message.toMap());
    await _sessions(uid).doc(sessionId).set(
      <String, Object>{
        'updatedAt': now,
        'lastMessagePreview': _preview(message.text),
      },
      SetOptions(merge: true),
    );
  }

  String _preview(String text) {
    final String compact = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 72) {
      return compact;
    }

    return '${compact.substring(0, 69)}...';
  }
}
