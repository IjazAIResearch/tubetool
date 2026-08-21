import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:tubegrow/screens/ai_studio_screen.dart';
import 'package:tubegrow/screens/seo_engine_screen.dart';
import 'package:tubegrow/screens/radar_screen.dart';
import 'package:tubegrow/screens/thumbnail_downloader_screen.dart';
import 'package:tubegrow/screens/video_analysis_screen.dart';
import 'package:tubegrow/screens/channel_analysis_screen.dart';
import 'package:tubegrow/screens/settings_screen.dart';
import 'package:tubegrow/services/youtube_url_service.dart';
import '../app_theme.dart';
import '../l10n/translations.dart';
import '../main.dart';

// ── Daily growth tips pool ────────────────────────────────────────────────────
const List<String> _dailyTips = [
  '💡 Post at peak times: Tue–Thu between 2 PM – 4 PM for highest views.',
  '🏷️ Use 15–20 tags mixing short & long-tail keywords for better discovery.',
  '📌 Pin a comment with a CTA in the first hour — boosts algorithm ranking.',
  '🎯 Your title\'s first 3 words decide your CTR. Make them count!',
  '📊 Shorts can drive 10× traffic to your long-form content — post one today.',
  '🔔 Ask subscribers to enable bell notifications in every video.',
  '✏️ Write descriptions with 200+ words containing your main keyword 3× times.',
  '📈 Reply to every comment in the first 24 hours to trigger the algorithm.',
  '🎬 End screens with a "watch next" suggestion increase session time by 40%.',
  '🔍 Check trending videos in your niche weekly to find content gaps.',
  '⏱️ Chapters (timestamps) increase average view duration significantly.',
  '🖼️ High-contrast thumbnails with a close-up face get 38% higher CTR.',
  '📅 Upload consistently — YouTube rewards channels with a regular schedule.',
  '🤝 Collaborate with creators in your niche to cross-grow audiences.',
  '💬 Turn top comments into Community Posts — free extra impressions!',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  late Box _searchHistoryBox;
  List<String> _recentSearches = [];
  late AnimationController _staggerController;

  // Retention data
  int _streakDays = 0;
  String _dailyTip = '';

  @override
  void initState() {
    super.initState();
    _searchHistoryBox = Hive.box('search_history');
    _loadRecentSearches();
    _initRetentionData();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternetAndAlert();
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNone = results.isEmpty || results.contains(ConnectivityResult.none);
      if (hasNone && mounted) _checkInternetAndAlert();
    });
  }

  void _initRetentionData() {
    try {
      final box = Hive.box('settings');
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final lastOpen = box.get('streak_last_date', defaultValue: '') as String;
      int streak = box.get('streak_days', defaultValue: 0) as int;

      if (lastOpen == today) {
        // Same day
      } else if (lastOpen == _yesterday()) {
        streak++;
        box.put('streak_days', streak);
        box.put('streak_last_date', today);
      } else if (lastOpen.isEmpty) {
        streak = 1;
        box.put('streak_days', 1);
        box.put('streak_last_date', today);
      } else {
        streak = 1;
        box.put('streak_days', 1);
        box.put('streak_last_date', today);
      }
      _streakDays = streak;

      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
      _dailyTip = _dailyTips[dayOfYear % _dailyTips.length];
    } catch (e) {
      debugPrint('[HomeScreen] Retention error: $e');
    }
  }

  String _yesterday() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return d.toIso8601String().substring(0, 10);
  }

  void _loadRecentSearches() {
    final history = _searchHistoryBox.get('urls', defaultValue: <String>[]);
    _recentSearches = List<String>.from(history);
  }

  void _addToSearchHistory(String url) {
    _recentSearches.remove(url);
    _recentSearches.insert(0, url);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.take(8).toList();
    }
    _searchHistoryBox.put('urls', _recentSearches);
    setState(() {});
  }

  void _clearSearchHistory() {
    _recentSearches.clear();
    _searchHistoryBox.put('urls', <String>[]);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.historyCleared)),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _urlController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetAndAlert() async {
    final result = await Connectivity().checkConnectivity();
    final isConnected = !result.contains(ConnectivityResult.none) && result.isNotEmpty;
    if (!isConnected && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
          title: Text(AppStrings.noInternet,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(AppStrings.noInternetMsg, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.ok),
              onPressed: () {
                Navigator.of(ctx).pop();
                _checkInternetAndAlert();
              },
            ),
          ],
        ),
      );
    }
    return isConnected;
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _handleUrlInput(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    _addToSearchHistory(trimmed);

    final videoId = YouTubeUrlService.extractVideoId(trimmed);
    if (videoId != null) {
      _navigateToScreen(VideoAnalysisScreen(videoUrl: trimmed));
      return;
    }

    final channelId = YouTubeUrlService.extractChannelId(trimmed);
    final username = YouTubeUrlService.extractUsername(trimmed);

    if (channelId != null || username != null || !trimmed.contains('/')) {
      _navigateToScreen(ChannelAnalysisScreen(channelUrl: trimmed));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid YouTube video or channel URL\n'
            'Examples:\n'
            '• youtube.com/watch?v=ID\n'
            '• youtu.be/ID\n'
            '• youtube.com/@username',
          ),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
      _handleUrlInput(_urlController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/appicon.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'TubeTool',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PRO',
                    style: TextStyle(
                      color: primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (_streakDays > 0)
              Text(
                '🔥 $_streakDays-day streak',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(themeModeNotifier: themeModeNotifier),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSmartInspectorHero(isDark),
            if (_recentSearches.isNotEmpty) _buildRecentSearches(isDark),
            const SizedBox(height: 14),
            _buildSectionTitle('Creator Power Tools'),
            const SizedBox(height: 10),
            _buildPowerToolsGrid(isDark),
            const SizedBox(height: 16),
            _buildDailyTipCard(isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Hero Smart Inspector ───────────────────────────────────────────────────
  Widget _buildSmartInspectorHero(bool isDark) {
    const primary = AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF5277)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universal URL Inspector',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Paste any video or channel to extract tags, HD thumbnails & SEO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            onSubmitted: _handleUrlInput,
            decoration: InputDecoration(
              hintText: 'Paste YouTube link or @handle...',
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_urlController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _urlController.clear()),
                    ),
                  IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    tooltip: 'Paste from clipboard',
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _handleUrlInput(_urlController.text),
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Inspect & Extract Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Power Tools 2x2 Grid ───────────────────────────────────────────────────
  Widget _buildPowerToolsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _buildToolCard(
          title: 'AI Creator Studio',
          subtitle: 'Hooks, Scripts & Co-Pilot',
          icon: Icons.auto_awesome,
          color: const Color(0xFFFF3366),
          isDark: isDark,
          onTap: () => _navigateToScreen(const AIStudioScreen()),
        ),
        _buildToolCard(
          title: 'SEO & Tag Lab',
          subtitle: 'Keywords & Viral Tags',
          icon: Icons.tag,
          color: const Color(0xFF6366F1),
          isDark: isDark,
          onTap: () => _navigateToScreen(const SEOEngineScreen()),
        ),
        _buildToolCard(
          title: 'HD Thumbnails',
          subtitle: '4K Downloads & Color Test',
          icon: Icons.image_outlined,
          color: const Color(0xFF10B981),
          isDark: isDark,
          onTap: () => _navigateToScreen(const ThumbnailDownloaderScreen()),
        ),
        _buildToolCard(
          title: 'Radar & Trends',
          subtitle: 'Viral Tracker & Channels',
          icon: Icons.radar,
          color: const Color(0xFF06B6D4),
          isDark: isDark,
          onTap: () => _navigateToScreen(const RadarScreen()),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Searches ────────────────────────────────────────────────────────
  Widget _buildRecentSearches(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Inspections',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            GestureDetector(
              onTap: _clearSearchHistory,
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentSearches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = _recentSearches[index];
              return ActionChip(
                label: Text(
                  url.replaceAll('https://', '').replaceAll('www.', ''),
                  style: const TextStyle(fontSize: 12),
                ),
                avatar: const Icon(Icons.history, size: 14),
                onPressed: () {
                  _urlController.text = url;
                  _handleUrlInput(url);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Daily Growth Tip ───────────────────────────────────────────────────────
  Widget _buildDailyTipCard(bool isDark) {
    if (_dailyTip.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2430), const Color(0xFF161B22)]
              : [const Color(0xFFFFF1F2), const Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Growth Tip',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dailyTip,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}
