import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:tubegrow/screens/main_navigation_screen.dart';
import 'package:tubegrow/l10n/translations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Pulse animation for final CTA button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Counter animation for social proof slide
  late AnimationController _counterController;
  late Animation<double> _counterAnim;

  // Total 4 slides
  static const int _totalSlides = 4;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _counterAnim = CurvedAnimation(parent: _counterController, curve: Curves.easeOut);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // Start counter animation when reaching the social proof slide (index 3)
    if (index == 3) {
      _counterController.forward(from: 0);
    }
  }

  Future<void> _finishOnboarding() async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _counterController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _currentPage == _totalSlides - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildSlide1(isDark),
                _buildSlide2(isDark),
                _buildSlide3(isDark),
                _buildSlide4(isDark),
              ],
            ),

            // Skip button (top-right)
            Positioned(
              top: 16, right: 24,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isLast ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: isLast,
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      AppStrings.skip,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Dots + Next/Get Started
            Positioned(
              bottom: 40, left: 24, right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Animated pill-dots
                  Row(
                    children: List.generate(_totalSlides, (i) =>
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 10,
                        width: _currentPage == i ? 24 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),

                  // CTA button
                  isLast
                    ? ScaleTransition(
                        scale: _pulseAnim,
                        child: ElevatedButton.icon(
                          onPressed: _finishOnboarding,
                          icon: const Icon(Icons.rocket_launch, size: 18),
                          label: Text(
                            AppStrings.getStarted,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6F00FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 10,
                            shadowColor: const Color(0xFF6F00FF).withOpacity(0.5),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 2,
                        ),
                        child: Text(AppStrings.next,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SLIDE 1: AI Assistant — "Your Personal YouTube AI" ──────────────────────
  Widget _buildSlide1(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white70 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mock AI chat bubble preview
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF6F00FF), Color(0xFF00C6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6F00FF).withOpacity(0.45),
                  blurRadius: 32, offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chatBubble('How do I get more views?', isUser: true),
                const SizedBox(height: 10),
                _chatBubble(
                  '🚀 Here are 5 proven strategies:\n1. Optimize your title with power words\n2. Post Shorts to drive traffic\n3. Use 15+ relevant tags\n4. Reply to every comment in the first hour\n5. Use end screens to chain videos',
                  isUser: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(AppStrings.obTitle1,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, height: 1.25)),
          const SizedBox(height: 14),
          Text(AppStrings.obDesc1,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subColor, height: 1.55)),
        ],
      ),
    );
  }

  Widget _chatBubble(String text, {required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
      ),
    );
  }

  // ── SLIDE 2: Tag Extractor — "Never Guess What Works" ────────────────────────
  Widget _buildSlide2(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white70 : Colors.black54;
    final tags = ['flutter tutorial', 'dart programming', 'mobile app', 'coding tips', 'UI design', 'state management', 'flutter widgets', 'beginner guide'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mock tag extractor result
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF512F), Color(0xFFF09819)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF512F).withOpacity(0.45),
                  blurRadius: 32, offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.local_offer, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text('Tags Extracted: 8', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Copy All', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(AppStrings.obTitle2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, height: 1.25)),
          const SizedBox(height: 14),
          Text(AppStrings.obDesc2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subColor, height: 1.55)),
        ],
      ),
    );
  }

  // ── SLIDE 3: SEO Score — "Rank #1 with AI SEO" ───────────────────────────────
  Widget _buildSlide3(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white70 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mock SEO score card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1D976C), Color(0xFF93F9B9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D976C).withOpacity(0.45),
                  blurRadius: 32, offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('SEO Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                // Circular score indicator
                SizedBox(
                  width: 100, height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 0.82,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        color: Colors.white,
                        strokeCap: StrokeCap.round,
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('82', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          Text('/100', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Mini improvement bars
                ...[
                  ('Title', 0.95),
                  ('Tags', 0.80),
                  ('Description', 0.65),
                ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(item.$1, style: const TextStyle(color: Colors.white, fontSize: 11))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.$2,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            color: Colors.white,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${(item.$2 * 100).toInt()}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(AppStrings.obTitle3,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, height: 1.25)),
          const SizedBox(height: 14),
          Text(AppStrings.obDesc3,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subColor, height: 1.55)),
        ],
      ),
    );
  }

  // ── SLIDE 4 (NEW): Social Proof — Animated counters ─────────────────────────
  Widget _buildSlide4(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Star row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (_) =>
              const Icon(Icons.star_rounded, color: Colors.amber, size: 28)),
          ),
          const SizedBox(height: 20),

          Text('Join 10,000+ YouTubers Growing Faster',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold,
              color: textColor, height: 1.25,
            )),
          const SizedBox(height: 14),
          Text(
            'TubeTool gives you the exact AI tools top creators use to beat the algorithm every day.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subColor, height: 1.55),
          ),
          const SizedBox(height: 32),

          // Animated stat counters
          AnimatedBuilder(
            animation: _counterAnim,
            builder: (_, __) {
              final creators   = (10000 * _counterAnim.value).toInt();
              final tools      = (14    * _counterAnim.value).toInt();
              final rating     = 4.7 * _counterAnim.value;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statCard('${_fmt(creators)}+', 'Creators', Icons.people, const Color(0xFF6F00FF)),
                  _statCard('$tools', 'AI Tools',  Icons.auto_awesome, const Color(0xFFFF512F)),
                  _statCard(rating.toStringAsFixed(1), 'Rating', Icons.star, Colors.amber.shade700),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Creator quotes
          _quoteCard('Rahul S.', 'Got from 500 to 8K subscribers in 3 months using TubeTool AI!', const Color(0xFF6F00FF)),
          const SizedBox(height: 10),
          _quoteCard('Sara K.', 'The tag extractor alone doubled my video impressions. Worth it!', const Color(0xFF1D976C)),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _quoteCard(String name, String quote, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.15),
            child: Text(name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                Text('"$quote"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}K' : '$n';
}
