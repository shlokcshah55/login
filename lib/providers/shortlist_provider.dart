import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';

/// Lightweight in-memory shortlist for active planning.
///
/// Shortlist ≠ Saved.
/// • **Saved** → long-term / passive bookmarks (persisted in Supabase).
/// • **Shortlist** → ephemeral "where should we go right now?" planning list.
///
/// Designed so backend persistence can be added later without changing the API.
class ShortlistProvider extends ChangeNotifier {
  final List<LocationModel> _items = [];

  // ── Getters ──────────────────────────────────────────────────

  List<LocationModel> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  bool contains(int locationId) =>
      _items.any((loc) => loc.locationId == locationId);

  // ── Mutators ─────────────────────────────────────────────────

  void add(LocationModel location) {
    if (contains(location.locationId)) return; // idempotent
    _items.add(location);
    notifyListeners();
  }

  void remove(int locationId) {
    _items.removeWhere((loc) => loc.locationId == locationId);
    notifyListeners();
  }

  void toggle(LocationModel location) {
    if (contains(location.locationId)) {
      remove(location.locationId);
    } else {
      add(location);
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
