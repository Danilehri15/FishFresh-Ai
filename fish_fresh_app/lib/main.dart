import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/app_provider.dart';
import 'ui/core/theme.dart';
import 'ui/features/home/home_view.dart';
import 'ui/features/account/account_view.dart';
import 'ui/features/heatmap/heatmap_view.dart';
import 'ui/features/market/market_view.dart';
import 'ui/features/chatbot/chatbot_view.dart';
import 'ui/features/catalog/catalog_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
      child: const FishFreshApp(),
    ),
  );
}

class FishFreshApp extends StatelessWidget {
  const FishFreshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FishFresh AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeView(),
    AccountView(),
    HeatmapView(),
    MarketView(),
    CatalogView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF6A1B9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A1B9A).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotView()),
              );
            },
            child: const Center(
              child: Icon(Icons.smart_toy, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          if (idx >= _screens.length) {
            setState(() => _currentIndex = _screens.length - 1);
          } else {
            setState(() => _currentIndex = idx);
          }
        },
        indicatorColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primaryTeal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.primaryTeal),
            label: 'Account',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppTheme.primaryTeal),
            label: 'Heatmap',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: AppTheme.primaryTeal),
            label: 'Prices',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: AppTheme.primaryTeal),
            label: 'Species',
          ),
        ],
      ),
    );
  }
}
