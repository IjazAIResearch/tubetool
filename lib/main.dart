import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_theme.dart';
import 'models/hive_adapters.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/ai_yt_helper_screen.dart';
import 'screens/tag_extractor_screen.dart';
import 'screens/trending_videos_screen.dart';
import 'screens/notes_list_screen.dart';
import 'screens/title_tester_screen.dart';
import 'screens/seo_score_screen.dart';
import 'screens/hashtag_generator_screen.dart';
import 'screens/keyword_suggestion_screen.dart';
import 'screens/best_time_screen.dart';
import 'screens/competitor_screen.dart';
import 'services/notification_service.dart';
import 'l10n/translations.dart';

/// Global navigator key — lets NotificationService navigate from outside
/// the widget tree when a notification is tapped.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Stores a pending payload if the app was launched from a notification
/// but the UI hasn't been built yet.
String? pendingDeepLinkPayload;

// Global theme notifier
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

// Global language notifier — triggers full app rebuild on language change
final ValueNotifier<String> languageNotifier = ValueNotifier('en');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive Adapters
  Hive.registerAdapter(TagTopicAdapter());
  Hive.registerAdapter(SavedNoteAdapter());

  // Open Hive boxes
  await Hive.openBox('settings');
  await Hive.openBox('saved_tags');
  await Hive.openBox('saved_notes');
  await Hive.openBox('search_history');

  // Load saved theme mode
  final settingsBox = Hive.box('settings');
  final themeIndex = settingsBox.get('themeMode', defaultValue: 0);
  themeModeNotifier.value = ThemeMode.values[themeIndex];

  // Load saved language
  final savedLang = settingsBox.get('language', defaultValue: 'en');
  languageNotifier.value = savedLang;
  AppStrings.lang = savedLang;

  // Initialize local notifications + wire deep-link handler
  await NotificationService.instance.init();
  NotificationService.onNotificationTap = _handleNotificationDeepLink;

  runApp(const TubeToolApp());
}

/// Navigates to the correct screen based on notification payload.
void _handleNotificationDeepLink(String payload) {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    pendingDeepLinkPayload = payload;
    return;
  }

  Widget screen;
  switch (payload) {
    case 'ai_assistant':      screen = const AIYTHelperScreen(); break;
    case 'tag_extractor':     screen = const TagExtractorScreen(); break;
    case 'trending_videos':   screen = const TrendingVideosScreen(); break;
    case 'script_writer':     screen = const NotesListScreen(); break;
    case 'title_tester':      screen = const TitleTesterScreen(); break;
    case 'seo_score':         screen = const SeoScoreScreen(); break;
    case 'hashtag_generator': screen = const HashtagGeneratorScreen(); break;
    case 'keyword_suggestion':screen = const KeywordSuggestionScreen(); break;
    case 'best_upload_time':  screen = const BestTimeScreen(); break;
    case 'competitor':        screen = const CompetitorScreen(); break;
    default:                  screen = const MainNavigationScreen();
  }

  // Push on top of whatever is currently visible
  nav.push(MaterialPageRoute(builder: (_) => screen));
}

class TubeToolApp extends StatefulWidget {
  const TubeToolApp({super.key});

  @override
  State<TubeToolApp> createState() => _TubeToolAppState();
}

class _TubeToolAppState extends State<TubeToolApp> {
  @override
  void initState() {
    super.initState();
    // Schedule 7 days of growth reminders
    NotificationService.instance.scheduleWeeklyNotifications();
    NotificationService.instance.scheduleReengagementNotification();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (context, langCode, _) {
            AppStrings.lang = langCode;
            return MaterialApp(
              title: 'TubeTool',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              navigatorKey: navigatorKey,
              home: const SplashScreen(),
              debugShowCheckedModeBanner: false,
              // ── Localization ──
              locale: Locale(langCode),
              supportedLocales: AppStrings.supportedLanguages
                  .map((l) => Locale(l['code']!))
                  .toList(),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Animated Splash Screen ───
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeIn),
      ),
    );

    _slideAnim = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        bool hasSeenOnboarding = false;
        if (Hive.isBoxOpen('settings')) {
          hasSeenOnboarding = Hive.box('settings').get('hasSeenOnboarding', defaultValue: false);
        }

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => hasSeenOnboarding
                ? const MainNavigationScreen()
                : const OnboardingScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );

        // Process any pending notification tap after the home screen has mounted
        Future.delayed(const Duration(milliseconds: 300), () {
          if (pendingDeepLinkPayload != null) {
            _handleNotificationDeepLink(pendingDeepLinkPayload!);
            pendingDeepLinkPayload = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3366).withOpacity(0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icons/splash.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFFF3366),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Animated title
                Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: const Text(
                      'TubeTool',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Animated subtitle
                Opacity(
                  opacity: _fadeAnim.value,
                  child: Text(
                    'Creator Studio & YouTube AI',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                // Progress indicator
                Opacity(
                  opacity: _fadeAnim.value,
                  child: const SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white12,
                        color: Color(0xFFFF3366),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
