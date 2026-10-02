import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../core/theme.dart';
import '../scan/scanner_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../scan/result_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final sub = state.subscription;
    final scansRemaining = sub?.scansRemainingToday ?? 20;
    final isPremium = sub?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.waves, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('FishFresh AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshData(),
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isLoggedIn && state.userName.isNotEmpty) ...[
                Text(
                  'Welcome back, ${state.userName.split(' ')[0]}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'Welcome to FishFresh!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Quota & Subscription Pill Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPremium
                        ? [const Color(0xFFD4AF37), const Color(0xFFAA7C11)]
                        : [AppTheme.primaryDark, AppTheme.primaryTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isPremium
                                  ? const Color(0xFFD4AF37)
                                  : AppTheme.primaryTeal)
                              .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Icon(
                        isPremium ? Icons.workspace_premium : Icons.bolt,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPremium
                                ? 'Premium Plan (Unlimited)'
                                : 'Free Tier Plan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPremium
                                ? 'Unlimited Daily AI Scans Active'
                                : '$scansRemaining of 20 Free Scans Remaining Today',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Mini Dashboard
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'AI Species',
                      '8',
                      Icons.set_meal,
                      AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Your Scans',
                      '${state.scanHistory.length}',
                      Icons.person,
                      AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScannerView(initialTab: 0),
                      ),
                    );
                  },
                  child:
                      Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00B4D8),
                                  Color(0xFF00796B),
                                  Color(0xFF2E7D32),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00796B,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.set_meal,
                                  size: 85,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'TAP TO SCAN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Fish, Eye, or Gills',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.06, 1.06),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          )
                          .shimmer(duration: 2500.ms, color: Colors.white24),
                ),
              ),
              const SizedBox(height: 30),

              // 4. Recent Scans Section
              if (state.scanHistory.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Scans',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    Text(
                      '${state.scanHistory.length} recorded',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.scanHistory.take(3).length,
                  itemBuilder: (context, idx) {
                    final item = state.scanHistory[idx];
                    final isFresh = item.freshness?.isFresh ?? true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isFresh
                              ? AppTheme.freshGreen.withValues(alpha: 0.15)
                              : AppTheme.spoiledRed.withValues(alpha: 0.15),
                          child: Icon(
                            isFresh ? Icons.check_circle : Icons.warning,
                            color: isFresh
                                ? AppTheme.freshGreen
                                : AppTheme.spoiledRed,
                          ),
                        ),
                        title: Text(
                          item.species?.displayName ?? 'Fish Scan',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.freshness?.status.toUpperCase()} • ${item.shelfLife?.refrigeratedHours ?? 0}h chilled shelf-life',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultView(result: item),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

