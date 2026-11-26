import 'package:flutter/material.dart';

import 'google_logo.dart';

/// Android/iOS/desktop: custom button that opens the native Google picker.
Widget buildGoogleButton({
  required bool isLogin,
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3C4043),
        side: BorderSide(color: Colors.grey.shade300, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF4285F4),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GoogleLogo(size: 22),
                const SizedBox(width: 12),
                Text(
                  isLogin ? 'Continue with Google' : 'Sign up with Google',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3C4043),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
    ),
  );
}
