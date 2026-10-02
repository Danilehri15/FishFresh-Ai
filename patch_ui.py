import os

path = r'C:\Users\daniy\OneDrive\Desktop\FYP Project\fish_fresh_app\lib\ui\features\account\account_view.dart'

content = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../core/theme.dart';

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
      error = await appState.register(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
    }
    
    setState(() => _isLoading = false);
    
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.spoiledRed));
    }
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_sync, size: 64, color: AppTheme.primaryTeal),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join Fish Fresh',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync your scans to MongoDB Cloud',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  if (!_isLogin)
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _submit(appState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(_isLogin ? 'Login' : 'Sign Up', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login"),
                  )
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
    
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => appState.logout(),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.2),
                    child: Text(
                      appState.userName.isNotEmpty ? appState.userName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.userName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(isPremium ? Icons.star : Icons.star_border, 
                                size: 16, color: isPremium ? Colors.orange : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              isPremium ? 'Premium Member' : 'Free Plan',
                              style: TextStyle(
                                color: isPremium ? Colors.orange : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium, color: AppTheme.primaryTeal),
                        const SizedBox(width: 8),
                        Text('Upgrade to Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Get unlimited scans, priority AI chat, and real-time market alerts for Rs. 999/month.'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => appState.upgradeToPremium(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Upgrade Now (Google Pay)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Text('My Scan History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (appState.scanHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No scans yet. Go to the Scanner tab to analyze a fish!'),
              ),
            )
          else
            ...appState.scanHistory.map((scan) {
              final isFresh = scan.freshness?.isFresh ?? false;
              final speciesName = scan.species?.displayName.toUpperCase() ?? "UNKNOWN FISH";
              final score = scan.freshness?.confidencePercent ?? 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isFresh ? AppTheme.freshGreen : AppTheme.spoiledRed,
                    child: Icon(isFresh ? Icons.check : Icons.warning, color: Colors.white),
                  ),
                  title: Text(speciesName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('\% Fresh'),
                  trailing: Text(scan.scannedAt.toString().substring(0, 10)),
                ),
              );
            }),
        ],
      ),
    );
  }
}
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
