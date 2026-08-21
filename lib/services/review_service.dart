// lib/services/review_service.dart
//
// Triggers the Google Play in-app review dialog at the best possible moment:
//  • User has opened the app on 3+ different days
//  • User has used 5+ different features
//  • The prompt has never been shown before
//  • We are at a "success moment" (e.g., tags copied, AI gave answer)

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:in_app_review/in_app_review.dart';

class ReviewService {
  ReviewService._();
  static final instance = ReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _kPromptShown      = 'review_prompt_shown';
  static const String _kDaysUsed         = 'review_days_used';
  static const String _kLastUsedDate     = 'review_last_date';
  static const String _kFeaturesUsed     = 'review_features_used';
  static const int    _minDays           = 3;
  static const int    _minFeatures       = 5;

  // ── Track a feature use ───────────────────────────────────────────────────

  /// Call this every time a user gets a successful result in any feature.
  /// [featureKey] should be a short stable string, e.g. 'tag_extractor'.
  Future<void> recordFeatureUse(String featureKey) async {
    try {
      final box = Hive.box('settings');
      box.put('last_used_feature_key', featureKey); // NEW
      // Track unique days
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastDate = box.get(_kLastUsedDate) as String?;
      int days = box.get(_kDaysUsed, defaultValue: 0) as int;
      if (lastDate != today) {
        days++;
        box.put(_kDaysUsed, days);
        box.put(_kLastUsedDate, today);
      }
      // Track unique features
      final features = List<String>.from(
        box.get(_kFeaturesUsed, defaultValue: <String>[]) as List,
      );
      if (!features.contains(featureKey)) {
        features.add(featureKey);
        box.put(_kFeaturesUsed, features);
      }
      debugPrint('[ReviewService] Recorded feature=$featureKey days=$days features=${features.length}');
    } catch (e) {
      debugPrint('[ReviewService] Error recording feature use: $e');
    }
  }

  // ── Try to show the review dialog ────────────────────────────────────────

  /// Call this after a clear success moment. The dialog only shows when all
  /// conditions are met and has never been shown before.
  Future<void> tryShowReview() async {
    try {
      final box = Hive.box('settings');
      // Already shown before? Never repeat.
      if (box.get(_kPromptShown, defaultValue: false) as bool) return;

      final days     = box.get(_kDaysUsed,     defaultValue: 0)    as int;
      final features = box.get(_kFeaturesUsed, defaultValue: <String>[]) as List;

      if (days < _minDays || features.length < _minFeatures) {
        debugPrint('[ReviewService] Conditions not met: days=$days features=${features.length}');
        return;
      }

      final available = await _inAppReview.isAvailable();
      if (!available) {
        debugPrint('[ReviewService] In-app review not available on this device');
        return;
      }

      debugPrint('[ReviewService] ✅ Showing in-app review prompt');
      await _inAppReview.requestReview();
      box.put(_kPromptShown, true);
    } catch (e) {
      debugPrint('[ReviewService] Error showing review: $e');
    }
  }
}
