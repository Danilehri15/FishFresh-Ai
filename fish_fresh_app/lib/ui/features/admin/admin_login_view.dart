import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../data/services/admin_api_service.dart';
import '../../../data/services/google_auth_service.dart';
import '../../core/theme.dart';
import '../account/google_btn.dart';
import 'admin_dashboard_view.dart';

/// Admin sign-in: Google (first sign-in also creates the admin's account)
/// or email + password. Only emails allow-listed on the server get in.
class AdminLoginView extends StatefulWidget {
  const AdminLoginView({super.key});

  @override
  State<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<AdminLoginView> {
  final _api = AdminApiService.instance;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;
  bool _loading = true;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    GoogleAuthService.adminMode = true;
    _init();
  }

  Future<void> _init() async {
    if (await _api.restoreSession()) {
      _openDashboard();
      return;
    }
    try {
      await GoogleAuthService.ensureInitialized();
      _googleSub = GoogleAuthService.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) _onGoogleUser(event.user);
        },
        onError: (Object e) => _fail(e is GoogleSignInException
            ? (e.description ?? e.code.name)
            : '$e'),
      );
    } catch (e) {
      debugPrint('[Admin] Google init error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    GoogleAuthService.adminMode = false;
    _googleSub?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _openDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminDashboardView()),
    );
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = msg;
    });
  }

  Future<void> _onGoogleUser(GoogleSignInAccount account) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      _fail('Google did not return an ID token. Please try again.');
      return;
    }
    try {
      await _api.loginWithGoogle(idToken);
      _openDashboard();
    } catch (e) {
      await GoogleAuthService.signOut();
      _fail('$e');
    }
  }

  Future<void> _onGooglePressed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await GoogleAuthService.signIn();
      if (account == null) _fail('Google sign-in was cancelled.');
      // Success continues in the authenticationEvents listener.
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> _loginWithPassword() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _fail('Enter your admin email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.loginWithPassword(_emailCtrl.text, _passCtrl.text);
      _openDashboard();
    } catch (e) {
      _fail('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Admin Portal'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        size: 60, color: AppTheme.primaryDark),
                    const SizedBox(height: 12),
                    const Text('Admin Sign In',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Authorised administrators only',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 22),
                    buildGoogleButton(
                      isLogin: true,
                      isLoading: _loading,
                      onPressed: _onGooglePressed,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'First Google sign-in creates your admin account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Admin email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _loginWithPassword(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.spoiledRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: AppTheme.spoiledRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppTheme.spoiledRed, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _loginWithPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white))
                            : const Text('Sign in as Admin',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
