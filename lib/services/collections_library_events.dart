import 'dart:async';

/// Simple app-wide broadcast for "the user's collection library changed".
///
/// Used to keep collection lists (e.g. Home dropdown) in sync when a collection
/// is created/edited/deleted from a different surface.
class CollectionsLibraryEvents {
  CollectionsLibraryEvents._();

  static final CollectionsLibraryEvents instance = CollectionsLibraryEvents._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notifyChanged() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }
}

