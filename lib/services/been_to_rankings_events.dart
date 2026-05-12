import 'dart:async';

/// Simple app-wide broadcast for "a user's been-to rankings changed".
///
/// Used to keep the Been To ranking section in sync when ratings are created
/// or edited from a different surface (e.g. ExpandedLocationCard).
class BeenToRankingsEvents {
  BeenToRankingsEvents._();

  static final BeenToRankingsEvents instance = BeenToRankingsEvents._();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get changes => _controller.stream;

  void notifyChanged(String userId) {
    if (_controller.isClosed) return;
    _controller.add(userId);
  }
}
