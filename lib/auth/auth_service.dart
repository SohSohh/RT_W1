import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  const AuthService._();

  static Future<void> signOut() => FirebaseAuth.instance.signOut();
}
