// Picks the right Google button per platform:
// - web: Google's official rendered button (required by google_sign_in v7)
// - mobile/desktop: our custom button that calls GoogleAuthService.signIn()
export 'google_btn_stub.dart' if (dart.library.js_interop) 'google_btn_web.dart';
