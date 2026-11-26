import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Real Google Sign-In (google_sign_in v7).
///
/// - Web: Google's own button (renderButton) triggers sign-in; results arrive
///   on [authenticationEvents]. `authenticate()` is NOT supported on web.
/// - Android/iOS: call [signIn] from our custom button; results also arrive
///   on [authenticationEvents].
class GoogleAuthService {
  /// OAuth 2.0 Web Client ID (also used as serverClientId on Android so the
  /// returned ID token's audience matches what the backend verifies).
  static const String webClientId =
      '336455024363-1gqe3p45ipi811po9cmn9ic7cq8q7sqe.apps.googleusercontent.com';

  static Future<void>? _initFuture;

  /// True while the admin login screen is open: Google sign-ins then go to the
  /// admin flow instead of logging into the normal user account.
  static bool adminMode = false;

  /// Must complete before rendering the web button or calling [signIn].
  static Future<void> ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: kIsWeb ? null : webClientId,
    );
  }

  /// Stream of sign-in / sign-out events from every platform.
  static Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  /// Whether a custom button may call [signIn] (false on web).
  static bool get supportsCustomButton =>
      GoogleSignIn.instance.supportsAuthenticate();

  /// Opens the native Google account picker (Android/iOS only).
  static Future<GoogleSignInAccount?> signIn() async {
    await ensureInitialized();
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
