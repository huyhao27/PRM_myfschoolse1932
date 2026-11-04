import '../models/user.dart';

/// Minimal in-memory session.
class Session {
  static String? token;
  static User? user;

  static void clear() {
    token = null;
    user = null;
  }
}
