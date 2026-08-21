import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'ai_studio_screen.dart';
import 'seo_engine_screen.dart';
import 'radar_screen.dart';
import '../app_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    AIStudioScreen(),
    SEOEngineScreen(),
    RadarScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppTheme.primaryColor;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Controlled via bottom nav
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: switchTab,
            backgroundColor: Colors.transparent,
            indicatorColor: primary.withOpacity(isDark ? 0.25 : 0.12),
            height: 65,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.flash_on_outlined),
                selectedIcon: Icon(Icons.flash_on, color: primary),
                label: 'Inspector',
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome, color: primary),
                label: 'AI Studio',
              ),
              NavigationDestination(
                icon: const Icon(Icons.tag_outlined),
                selectedIcon: Icon(Icons.tag, color: primary),
                label: 'SEO & Tags',
              ),
              NavigationDestination(
                icon: const Icon(Icons.radar_outlined),
                selectedIcon: Icon(Icons.radar, color: primary),
                label: 'Radar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
