import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';

class BubbleModeProvider with ChangeNotifier {
  Bubble? _pendingBubble;

  Bubble? get pendingBubble => _pendingBubble;
  bool get hasPendingActivation => _pendingBubble != null;

  void requestBubbleMode(Bubble bubble) {
    _pendingBubble = bubble;
    print('Requested bubble mode for bubble: ${bubble.name}');
    notifyListeners();
  }

  void clearPendingBubble() {
    _pendingBubble = null;
    notifyListeners();
  }
}
