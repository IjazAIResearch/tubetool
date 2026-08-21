// lib/services/notification_service.dart
//
// Schedules one local push notification per day at a random time between
// 9:00 AM and 9:00 PM. Each notification promotes a different app feature
// and carries a payload that deep-links the user to that feature screen.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ─── Notification model ──────────────────────────────────────────────────────

class NotificationItem {
  final String title;
  final String body;
  final String payload; // maps to a route in the navigator

  const NotificationItem({
    required this.title,
    required this.body,
    required this.payload,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Pool of 10 feature-specific notifications
  static const List<NotificationItem> _pool = [
    NotificationItem(
      title: '🤖 Got your next video idea?',
      body: 'Let your AI Co-Pilot brainstorm viral ideas for you right now!',
      payload: 'ai_assistant',
    ),
    NotificationItem(
      title: '🏷️ Steal your competitor\'s tags',
      body: 'Extract the exact tags top creators are using. Open TubeTool now!',
      payload: 'tag_extractor',
    ),
    NotificationItem(
      title: '🔥 What\'s trending in your niche?',
      body: 'See the hottest YouTube videos right now and get inspired!',
      payload: 'trending_videos',
    ),
    NotificationItem(
      title: '✏️ Your script won\'t write itself!',
      body: 'Open the AI Script Writer and start your next masterpiece.',
      payload: 'script_writer',
    ),
    NotificationItem(
      title: '🎯 Is your title click-worthy?',
      body: 'A/B test your video titles with AI and maximize your CTR!',
      payload: 'title_tester',
    ),
    NotificationItem(
      title: '📈 How\'s your channel SEO?',
      body: 'Check your SEO Score and find out what\'s holding you back.',
      payload: 'seo_score',
    ),
    NotificationItem(
      title: '# Power up your hashtags!',
      body: 'Generate smart hashtags for your next upload in seconds.',
      payload: 'hashtag_generator',
    ),
    NotificationItem(
      title: '💡 Find keywords viewers search for',
      body: 'Discover high-traffic keywords perfect for your next video.',
      payload: 'keyword_suggestion',
    ),
    NotificationItem(
      title: '⏰ Are you uploading at peak time?',
      body: 'Check the best upload time for your audience and gain more views!',
      payload: 'best_upload_time',
    ),
    NotificationItem(
      title: '🔍 Spy on your competitors',
      body: 'Analyze top channels in your niche and find the winning formula.',
      payload: 'competitor',
    ),
  ];

  // ─── Initialize ────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Initialize timezone database
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request Android 13+ POST_NOTIFICATIONS permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Check if the app was launched by a notification (from terminated state)
    final NotificationAppLaunchDetails? launchDetails =
        await _plugin.getNotificationAppLaunchDetails();
    
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final response = launchDetails.notificationResponse;
      if (response != null) {
        // Delay slightly to ensure main() has assigned the callback
        Future.microtask(() {
          _onNotificationTap(response);
        });
      }
    }
  }

  // ─── Schedule Next 7 Days (1 per day) ────────────────────────────────────

  Future<void> scheduleWeeklyNotifications() async {
    // 1. Cancel all previously scheduled notifications so we can start fresh
    await cancelAll();

    if (!Hive.isBoxOpen('settings')) return;
    final box = Hive.box('settings');
    final rng = Random();
    int lastIndex = box.get('notif_last_index', defaultValue: -1) as int;

    int notificationsScheduled = 0;
    int dayOffset = 0;

    // Keep looking forward days until we successfully schedule exactly 7 notifications
    while (notificationsScheduled < 7) {
      final targetDate = DateTime.now().add(Duration(days: dayOffset));
      
      // Random time between 9:00 AM and 9:00 PM (21:00)
      final randomHour = 9 + rng.nextInt(12);
      final randomMinute = rng.nextInt(60);

      final scheduledTime = tz.TZDateTime(
        tz.local,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        randomHour,
        randomMinute,
      );

      // Only schedule if this random time is actually in the future!
      if (scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
        
        // Pick a random notification from the pool (avoid repeating exactly same as previous day)
        int index;
        do {
          index = rng.nextInt(_pool.length);
        } while (index == lastIndex && _pool.length > 1);
        lastIndex = index;

        final notif = _pool[index];

        const androidDetails = AndroidNotificationDetails(
          'tubetool_daily',
          'Daily Growth Tips',
          channelDescription: 'Daily tips and reminders to grow your YouTube channel',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFF3366),
          styleInformation: BigTextStyleInformation(''),
        );

        final details = const NotificationDetails(android: androidDetails);

        try {
          await _plugin.zonedSchedule(
            notificationsScheduled + 1, // ID: 1 through 7
            notif.title,
            notif.body,
            scheduledTime,
            details,
            payload: notif.payload,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          notificationsScheduled++;
        } catch (e) {
          debugPrint('[NotificationService] zonedSchedule error: $e');
          break;
        }
      }
      
      dayOffset++; // move to the next day
    }

    // Save state
    await box.put('notif_last_index', lastIndex);
  }

  // ─── Re-engagement Notification (2 days inactive) ─────────────────────────

  Future<void> scheduleReengagementNotification() async {
    if (!Hive.isBoxOpen('settings')) return;
    final box = Hive.box('settings');
    final lastFeature = box.get('last_used_feature_key') as String?;
    
    String title = 'We miss you! 😢';
    String body = 'Come back and grow your YouTube channel with our AI tools today!';
    String payload = 'home';

    if (lastFeature == 'tag_extractor') {
      title = 'Need more tags? 🏷️';
      body = 'Your last video was great! Want to extract more competitor tags?';
      payload = 'tag_extractor';
    } else if (lastFeature == 'seo_score') {
      title = 'Improve your SEO Score 📈';
      body = 'Ready to rank #1? Analyze your next video SEO now.';
      payload = 'seo_score';
    } else if (lastFeature == 'ai_assistant') {
      title = 'Your AI Co-pilot is waiting 🤖';
      body = 'Got a new video idea? Let AI write the script for you.';
      payload = 'ai_assistant';
    }

    final targetDate = DateTime.now().add(const Duration(days: 2));
    final scheduledTime = tz.TZDateTime.from(targetDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'tubegrow_reengagement',
      'Re-engagement',
      channelDescription: 'Reminders when you haven\'t used the app in a while',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF6F00FF),
    );

    await _plugin.zonedSchedule(
      10, // specific ID to not overlap with weekly
      title,
      body,
      scheduledTime,
      const NotificationDetails(android: androidDetails),
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // ─── Cancel all pending notifications ────────────────────────────────────

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] cancelAll error: $e');
    }
  }

  // ─── Tap handler — navigates to feature screen ────────────────────────────
  // The navigator is wired in main.dart via navigatorKey.

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    debugPrint('[NotificationService] Tapped: $payload');
    // Deliver to the global handler registered in main.dart
    onNotificationTap?.call(payload);
  }

  /// Register this from main.dart to handle deep-link navigation
  static void Function(String payload)? onNotificationTap;
}
