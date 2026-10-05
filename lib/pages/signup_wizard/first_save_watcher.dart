import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase/constants.dart';
import '../../supabase/supabase_client.dart';

/// Detects the user's first saved place during onboarding.
///
/// Uses its own realtime channel on `user_location_actions` (the shared one
/// owned by `LocationHelper` must not be replaced) plus an explicit count
/// check, which the UI calls on app resume because the user leaves the app to
/// share from TikTok/Instagram and realtime may have dropped meanwhile.
class FirstSaveWatcher {
  FirstSaveWatcher({SupabaseClient? client, String? userId})
      : _client = client ?? SupabaseClientManager().client,
        _userId = userId ?? SupabaseClientManager().currentUser?.id;

  final SupabaseClient _client;
  final String? _userId;
  final StreamController<void> _controller = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  bool _fired = false;

  /// Emits once, when the first save is detected.
  Stream<void> get onFirstSave => _controller.stream;

  bool get hasFired => _fired;

  void start() {
    final userId = _userId;
    if (userId == null || _channel != null) return;
    _channel = _client
        .channel('onboarding_first_save:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.tableUserLocationActions,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: SupabaseConstants.columnUserId,
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord[SupabaseConstants.columnAction] ==
                SupabaseConstants.actionSave) {
              _fire();
            }
          },
        )
        .subscribe();
  }

  /// Re-checks the database. Call on resume and after a notes import.
  Future<bool> check() async {
    final userId = _userId;
    if (userId == null) return false;
    if (_fired) return true;
    try {
      final rows = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select(SupabaseConstants.columnLocationId)
          .eq(SupabaseConstants.columnUserId, userId)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .limit(1);
      if (rows.isNotEmpty) {
        _fire();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _controller.add(null);
  }

  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
    await _controller.close();
  }
}
