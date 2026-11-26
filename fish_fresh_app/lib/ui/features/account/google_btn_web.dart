import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web: renders Google's official "Sign in / Sign up with Google" button
/// (includes the real Google logo). Clicking it signs the user in and the
/// result is delivered via GoogleAuthService.authenticationEvents.
Widget buildGoogleButton({
  required bool isLogin,
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: Center(
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF4285F4),
              ),
            )
          : web.renderButton(
              configuration: web.GSIButtonConfiguration(
                type: web.GSIButtonType.standard,
                theme: web.GSIButtonTheme.outline,
                size: web.GSIButtonSize.large,
                shape: web.GSIButtonShape.rectangular,
                text: isLogin
                    ? web.GSIButtonText.continueWith
                    : web.GSIButtonText.signupWith,
                logoAlignment: web.GSIButtonLogoAlignment.left,
                minimumWidth: 300,
              ),
            ),
    ),
  );
}
