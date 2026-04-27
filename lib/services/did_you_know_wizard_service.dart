import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/did_you_know_wizard_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DidYouKnowWizardService {
  static const String _seenKeyPrefix = 'did_you_know_seen_';
  static const String _shownCountKeyPrefix = 'did_you_know_shown_count_';
  static const String _lastShownAtKey = 'did_you_know_last_shown_at';
  static const String _lastShownActionIdKey =
      'did_you_know_last_shown_action_id';
  static const String _dailyRollDateKey = 'did_you_know_daily_roll_date';
  static const String _dailyRollPassKey = 'did_you_know_daily_roll_pass';

  static const bool _previewTikTokWizardDartDefine =
      bool.fromEnvironment('PREVIEW_DID_YOU_KNOW_TIKTOK', defaultValue: false);

  static bool get previewTikTokWizardEnabled {
    return _previewTikTokWizardDartDefine;
  }

  static const Duration _globalCooldown = Duration(hours: 24);
  static const int _minActionsSinceLastTip = 5;
  static const double _dailyChance = 0.20;

  static bool _isChecking = false;

  final _client = SupabaseClientManager().client;

  Future<bool> hasSeen(DidYouKnowWizardId id) async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    return (await _getShownCount(userId, id)) > 0;
  }

  Future<void> markSeen(DidYouKnowWizardId id) async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await _incrementShownCount(prefs, userId, id);
  }

  Future<void> showPreviewTikTokWizard(BuildContext context) {
    return DidYouKnowWizardDialog.show(
      context,
      wizard: DidYouKnowWizards.tiktokSharing,
    );
  }

  Future<void> maybeShow(
    BuildContext context, {
    required DidYouKnowWizardId id,
    bool force = false,
  }) async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    if (!force && await hasSeen(id)) return;
    await DidYouKnowWizardDialog.show(
      context,
      wizard: DidYouKnowWizards.byId(id),
    );
    await markSeen(id);
  }

  /// Decides whether to show a "Did you know?" wizard, based on:
  /// - Global rarity: max 1 per 24h, require >=5 actions since last tip
  /// - Daily chance: ~20% per eligible active day
  /// - Priority: TikTok -> Bubbles -> Collections
  /// - Re-show once at higher thresholds if still unused
  Future<void> maybeShowBestTip(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_isChecking) return;
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;

    _isChecking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowUtc = DateTime.now().toUtc();

      if (!force) {
        final lastShownAt = _getLastShownAt(prefs, userId);
        if (lastShownAt != null &&
            nowUtc.difference(lastShownAt) < _globalCooldown) {
          return;
        }
        if (lastShownAt != null) {
          final lastShownActionId = prefs.getInt(
            _scopedKey(userId, _lastShownActionIdKey),
          );
          final hasEnoughNewActions = lastShownActionId != null
              ? await _hasAtLeastNNewActionsSinceActionId(
                  userId,
                  sinceActionId: lastShownActionId,
                  n: _minActionsSinceLastTip,
                )
              : await _hasAtLeastNNewActionsSinceTimestamp(
                  userId,
                  sinceUtc: lastShownAt,
                  n: _minActionsSinceLastTip,
                );
          if (!hasEnoughNewActions) return;
        }
      }

      final stats = await _fetchStats(userId);
      final tip = await _pickHighestPriorityEligibleTip(
        prefs,
        userId,
        stats,
      );

      if (tip == null) return;

      // Ship TikTok only for now. (Other wizards are implemented but gated off.)
      if (tip != DidYouKnowWizardId.tiktokSharing) return;

      if (!force && !_passesDailyChance(prefs, userId, nowUtc)) {
        return;
      }

      if (!context.mounted) return;
      await DidYouKnowWizardDialog.show(
        context,
        wizard: DidYouKnowWizards.byId(tip),
      );

      await _incrementShownCount(prefs, userId, tip);
      await prefs.setString(
        _scopedKey(userId, _lastShownAtKey),
        nowUtc.toIso8601String(),
      );
      final latestActionId = await _fetchLatestActionId(userId);
      if (latestActionId != null) {
        await prefs.setInt(
          _scopedKey(userId, _lastShownActionIdKey),
          latestActionId,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DidYouKnowWizardService] maybeShowBestTip error: $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Eligibility
  // ─────────────────────────────────────────────────────────────

  Future<DidYouKnowWizardId?> _pickHighestPriorityEligibleTip(
    SharedPreferences prefs,
    String userId,
    _WizardStats stats,
  ) async {
    // Priority 1: TikTok sharing
    final tiktokShown =
        await _getShownCount(userId, DidYouKnowWizardId.tiktokSharing);
    if (stats.socialSaves == 0) {
      if (tiktokShown == 0 && stats.totalSaves >= 7) {
        return DidYouKnowWizardId.tiktokSharing;
      }
      if (tiktokShown == 1 && stats.totalSaves >= 14) {
        return DidYouKnowWizardId.tiktokSharing;
      }
    }

    // Priority 2: Bubbles
    final bubblesShown =
        await _getShownCount(userId, DidYouKnowWizardId.bubbles);
    if (!stats.hasBubbleUsage) {
      if (bubblesShown == 0 &&
          (stats.totalSaves >= 8 || stats.activeDays >= 4)) {
        return DidYouKnowWizardId.bubbles;
      }
      if (bubblesShown == 1 && stats.totalSaves >= 20) {
        return DidYouKnowWizardId.bubbles;
      }
    }

    // Priority 3: Collections
    final collectionsShown =
        await _getShownCount(userId, DidYouKnowWizardId.collections);
    if (!stats.hasCollectionUsage) {
      if (collectionsShown == 0 &&
          stats.totalSaves >= 15 &&
          stats.activeDays >= 7) {
        return DidYouKnowWizardId.collections;
      }
      if (collectionsShown == 1 && stats.totalSaves >= 35) {
        return DidYouKnowWizardId.collections;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────

  Future<_WizardStats> _fetchStats(String userId) async {
    final saveRows = await _client
        .from(SupabaseConstants.tableUserLocationActions)
        .select(
            '${SupabaseConstants.columnSavedMethod}, ${SupabaseConstants.columnCreatedAt}')
        .eq(SupabaseConstants.columnUserId, userId)
        .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
        .eq('acked', true);

    final rows = (saveRows as List).whereType<Map>().toList();

    var totalSaves = 0;
    var inAppSaves = 0;
    var socialSaves = 0;
    final activeDayKeys = <String>{};

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      totalSaves++;
      final method = (row[SupabaseConstants.columnSavedMethod] ??
              SupabaseConstants.savedMethodInApp)
          .toString()
          .toLowerCase();
      if (method == SupabaseConstants.savedMethodInApp) {
        inAppSaves++;
      }
      if (method == SupabaseConstants.savedMethodTikTok ||
          method == 'instagram') {
        socialSaves++;
      }
      final createdAt = _parseDateTime(row[SupabaseConstants.columnCreatedAt]);
      if (createdAt != null) {
        final local = createdAt.toLocal();
        activeDayKeys.add('${local.year}-${local.month}-${local.day}');
      }
    }

    final hasBubbleUsage = await _hasAnyBubbleUsage(userId);
    final hasCollectionUsage = await _hasAnyCollectionUsage(userId);

    return _WizardStats(
      totalSaves: totalSaves,
      inAppSaves: inAppSaves,
      socialSaves: socialSaves,
      activeDays: activeDayKeys.length,
      hasBubbleUsage: hasBubbleUsage,
      hasCollectionUsage: hasCollectionUsage,
    );
  }

  Future<bool> _hasAnyBubbleUsage(String userId) async {
    final created = await _client
        .from(SupabaseConstants.tableBubbles)
        .select(SupabaseConstants.columnBubbleId)
        .eq(SupabaseConstants.columnCreatedBy, userId)
        .limit(1);
    if ((created as List).isNotEmpty) return true;

    final member = await _client
        .from(SupabaseConstants.tableBubbleMembers)
        .select('id')
        .eq(SupabaseConstants.columnUserId, userId)
        .limit(1);
    if ((member as List).isNotEmpty) return true;

    final bubbleSaves = await _client
        .from(SupabaseConstants.tableUserLocationActions)
        .select('action_id')
        .eq(SupabaseConstants.columnUserId, userId)
        .eq(SupabaseConstants.columnAction, 'bubble_save')
        .limit(1);
    return (bubbleSaves as List).isNotEmpty;
  }

  Future<bool> _hasAnyCollectionUsage(String userId) async {
    final created = await _client
        .from(SupabaseConstants.tableCollections)
        .select(SupabaseConstants.columnCollectionId)
        .eq(SupabaseConstants.columnCreatedBy, userId)
        .limit(1);
    if ((created as List).isNotEmpty) return true;

    final added = await _client
        .from(SupabaseConstants.tableCollectionLocations)
        .select('id')
        .eq('added_by', userId)
        .limit(1);
    return (added as List).isNotEmpty;
  }

  Future<int?> _fetchLatestActionId(String userId) async {
    final row = await _client
        .from(SupabaseConstants.tableUserLocationActions)
        .select('action_id')
        .eq(SupabaseConstants.columnUserId, userId)
        .order('action_id', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final value = row['action_id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<bool> _hasAtLeastNNewActionsSinceTimestamp(
    String userId, {
    required DateTime sinceUtc,
    required int n,
  }) async {
    final rows = await _client
        .from(SupabaseConstants.tableUserLocationActions)
        .select('action_id')
        .eq(SupabaseConstants.columnUserId, userId)
        .gt(SupabaseConstants.columnCreatedAt, sinceUtc.toIso8601String())
        .limit(n);
    return (rows as List).length >= n;
  }

  Future<bool> _hasAtLeastNNewActionsSinceActionId(
    String userId, {
    required int sinceActionId,
    required int n,
  }) async {
    final rows = await _client
        .from(SupabaseConstants.tableUserLocationActions)
        .select('action_id')
        .eq(SupabaseConstants.columnUserId, userId)
        .gt('action_id', sinceActionId)
        .limit(n);
    return (rows as List).length >= n;
  }

  // ─────────────────────────────────────────────────────────────
  // Storage
  // ─────────────────────────────────────────────────────────────

  DateTime? _getLastShownAt(SharedPreferences prefs, String userId) {
    final raw = prefs.getString(_scopedKey(userId, _lastShownAtKey));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<int> _getShownCount(String userId, DidYouKnowWizardId id) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedCountKey =
        _scopedKey(userId, '$_shownCountKeyPrefix${id.name}');
    final existing = prefs.getInt(scopedCountKey);
    if (existing != null) return existing;

    // Backwards-compat: old bool key means "seen once".
    final oldBoolKey = _scopedKey(userId, '$_seenKeyPrefix${id.name}');
    final scopedOldSeen = prefs.getBool(oldBoolKey);
    final unscopedOldSeen = prefs.getBool('$_seenKeyPrefix${id.name}');
    if (scopedOldSeen == true || unscopedOldSeen == true) {
      await prefs.setInt(scopedCountKey, 1);
      await prefs.setBool(oldBoolKey, true);
      return 1;
    }
    return 0;
  }

  Future<void> _incrementShownCount(
    SharedPreferences prefs,
    String userId,
    DidYouKnowWizardId id,
  ) async {
    final key = _scopedKey(userId, '$_shownCountKeyPrefix${id.name}');
    final current = await _getShownCount(userId, id);
    await prefs.setInt(key, current + 1);

    // Keep old key in sync for any legacy reads.
    await prefs.setBool(_scopedKey(userId, '$_seenKeyPrefix${id.name}'), true);
  }

  bool _passesDailyChance(
    SharedPreferences prefs,
    String userId,
    DateTime nowUtc,
  ) {
    final dayKey = '${nowUtc.year}-${nowUtc.month}-${nowUtc.day}';
    final storedDay = prefs.getString(_scopedKey(userId, _dailyRollDateKey));
    if (storedDay == dayKey) {
      return prefs.getBool(_scopedKey(userId, _dailyRollPassKey)) ?? false;
    }
    final pass = Random().nextDouble() < _dailyChance;
    prefs.setString(_scopedKey(userId, _dailyRollDateKey), dayKey);
    prefs.setBool(_scopedKey(userId, _dailyRollPassKey), pass);
    return pass;
  }

  String _scopedKey(String userId, String key) => '${key}_$userId';

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

@immutable
class _WizardStats {
  final int totalSaves;
  final int inAppSaves;
  final int socialSaves;
  final int activeDays;
  final bool hasBubbleUsage;
  final bool hasCollectionUsage;

  const _WizardStats({
    required this.totalSaves,
    required this.inAppSaves,
    required this.socialSaves,
    required this.activeDays,
    required this.hasBubbleUsage,
    required this.hasCollectionUsage,
  });
}
