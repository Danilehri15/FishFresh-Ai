import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../../data/services/google_auth_service.dart';
import '../../core/theme.dart';

import '../admin/admin_login_view.dart';
import 'google_btn.dart';
import 'google_logo.dart';

class AccountView extends StatefulWidget {
  const AccountView({super.key});
  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  Future<void> _submit(AppStateProvider appState) async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    if (!_isLogin && _nameCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);

    String? error;
    if (_isLogin) {
      error = await appState.login(_emailCtrl.text, _passCtrl.text);
    } else {
      error = await appState.register(
        _emailCtrl.text,
        _passCtrl.text,
        _nameCtrl.text,
      );
    }

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.spoiledRed),
      );
    }
  }

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;
  bool _googleReady = false;

  @override
  void initState() {
    super.initState();
    _initGoogle();
  }

  Future<void> _initGoogle() async {
    try {
      await GoogleAuthService.ensureInitialized();
      // Every successful Google sign-in (web rendered button OR mobile picker)
      // arrives here -> backend verifies token & creates/logs in the MongoDB user.
      _googleSub = GoogleAuthService.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn &&
              !GoogleAuthService.adminMode) {
            _completeGoogleLogin(event.user);
          }
        },
        onError: (Object e) => _showGoogleError(e),
      );
    } catch (e) {
      debugPrint('[GoogleAuth] Initialize error: $e');
    }
    if (mounted) setState(() => _googleReady = true);
  }

  @override
  void dispose() {
    _googleSub?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Mobile/desktop only — on web Google's own button starts the flow.
  Future<void> _onGoogleButtonPressed() async {
    setState(() => _isLoading = true);
    try {
      final account = await GoogleAuthService.signIn();
      // Success is handled by the authenticationEvents listener.
      if (account == null && mounted) setState(() => _isLoading = false);
    } catch (e) {
      _showGoogleError(e);
    }
  }

  Future<void> _completeGoogleLogin(GoogleSignInAccount account) async {
    if (!mounted) return;
    final appState = context.read<AppStateProvider>();
    if (appState.isLoggedIn) return;
    setState(() => _isLoading = true);

    final error = await appState.loginWithGoogle(
      email: account.email,
      name: account.displayName ?? account.email.split('@')[0],
      googleId: account.id,
      photoUrl: account.photoUrl,
      idToken: account.authentication.idToken,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      await GoogleAuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.spoiledRed),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const GoogleLogo(size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome ${account.displayName ?? account.email}!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E8E3E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showGoogleError(Object e) {
    debugPrint('[GoogleAuth] Google Sign-In error: $e');
    if (!mounted) return;
    setState(() => _isLoading = false);
    final msg = e is GoogleSignInException
        ? (e.description ?? e.code.name)
        : e.toString().replaceAll('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Google Sign-In failed: $msg'),
        backgroundColor: AppTheme.spoiledRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    if (!appState.isLoggedIn) {
      return _buildAuthScreen(appState);
    }
    return _buildProfileScreen(appState);
  }

  Widget _buildAuthScreen(AppStateProvider appState) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(_isLogin ? 'Login to Fish Fresh' : 'Create Account'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_sync, size: 60, color: AppTheme.primaryTeal),
                  const SizedBox(height: 14),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join Fish Fresh',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Login with Google or Email'
                        : 'Sign up with Google or Email',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Real Google Sign-In Button (Present on BOTH Login & Sign-Up screens)
                  // New users are auto-registered in MongoDB on first Google sign-in.
                  buildGoogleButton(
                    isLogin: _isLogin,
                    isLoading: _isLoading || !_googleReady,
                    onPressed: _onGoogleButtonPressed,
                  ),

                  const SizedBox(height: 20),

                  // "OR" Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR USE EMAIL',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (!_isLogin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _submit(appState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isLogin ? 'Login with Email' : 'Sign Up with Email',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Login",
                      style: TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: Colors.grey.shade200),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminLoginView()),
                    ),
                    icon: Icon(Icons.admin_panel_settings_outlined,
                        size: 20, color: Colors.grey.shade700),
                    label: Text(
                      'Admin Portal',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileScreen(AppStateProvider appState) {
    final sub = appState.subscription;
    final isPremium = sub?.isPremium == true;
    final isGoogle = appState.isGoogleUser;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => appState.logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: isGoogle
                                ? const Color(0xFF4285F4).withValues(alpha: 0.15)
                                : AppTheme.accentCyan.withValues(alpha: 0.2),
                            child: Text(
                              appState.userName.isNotEmpty
                                  ? appState.userName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isGoogle ? const Color(0xFF4285F4) : AppTheme.primaryDark,
                              ),
                            ),
                          ),
                          if (isGoogle)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const GoogleLogo(size: 14),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.userName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (appState.userEmail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  appState.userEmail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  isPremium ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: isPremium ? Colors.orange : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPremium
                                      ? (sub?.daysRemaining != null
                                          ? 'Premium · ${sub!.daysRemaining} days left'
                                          : 'Premium Member')
                                      : 'Free Plan',
                                  style: TextStyle(
                                    color: isPremium
                                        ? Colors.orange
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isGoogle ? const Color(0xFFE8F0FE) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isGoogle ? const Color(0xFFD2E3FC) : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isGoogle)
                          const GoogleLogo(size: 16)
                        else
                          Icon(Icons.cloud_done, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isGoogle
                                ? 'Authenticated via Google • Synced with MongoDB'
                                : 'Authenticated via Email • Synced with MongoDB',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isGoogle ? const Color(0xFF1967D2) : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!isPremium)
            Card(
              color: AppTheme.primaryTeal.withValues(alpha: 0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.workspace_premium, color: Color(0xFFD4AF37)),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Get unlimited scans, priority AI chat, and real-time market alerts for Rs. 999/month.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Select Payment Method'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.phone_android,
                                      color: Colors.green,
                                    ),
                                    title: const Text('Easypaisa'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      appState.upgradeTier('Easypaisa');
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.credit_card,
                                      color: Colors.blue,
                                    ),
                                    title: const Text('Credit Card'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      appState.upgradeTier('Credit Card');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Upgrade Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            'My Scan History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (appState.scanHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No scans yet. Go to the Scanner tab to analyze a fish!',
                ),
              ),
            )
          else
            ...appState.scanHistory.map((scan) {
              final isFresh = scan.freshness?.isFresh ?? false;
              final speciesName =
                  scan.species?.displayName.toUpperCase() ?? "UNKNOWN FISH";
              final score = scan.freshness?.confidencePercent ?? 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isFresh
                        ? AppTheme.freshGreen
                        : AppTheme.spoiledRed,
                    child: Icon(
                      isFresh ? Icons.check : Icons.warning,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    speciesName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${score.toStringAsFixed(1)}% Fresh'),
                  trailing: Text(scan.scannedAt.toString().substring(0, 10)),
                ),
              );
            }),
        ],
      ),
    );
  }
}
