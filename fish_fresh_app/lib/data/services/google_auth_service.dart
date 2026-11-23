import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (e) {
        debugPrint('[GoogleAuth] Initialize warning: $e');
      }
      _initialized = true;
    }
  }

  /// Triggers the real Google OAuth sign-in flow.
  static Future<GoogleSignInAccount?> signIn() async {
    await _ensureInitialized();
    try {
      return await GoogleSignIn.instance.authenticate();
    } catch (e) {
      debugPrint('[GoogleAuth] Sign-in error: $e');
      rethrow;
    }
  }

  /// Signs out the current Google user.
  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
