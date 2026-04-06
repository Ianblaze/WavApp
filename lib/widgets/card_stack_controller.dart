// lib/widgets/card_stack_controller.dart
import 'package:flutter/foundation.dart';

class CardStackController extends ChangeNotifier {
  VoidCallback? _triggerLike;
  VoidCallback? _triggerDislike;
  VoidCallback? _triggerShuffle;

  void attach({
    required VoidCallback triggerLike,
    required VoidCallback triggerDislike,
    VoidCallback? triggerShuffle,
  }) {
    _triggerLike    = triggerLike;
    _triggerDislike = triggerDislike;
    _triggerShuffle = triggerShuffle;
  }

  void detach() {
    _triggerLike    = null;
    _triggerDislike = null;
    _triggerShuffle = null;
  }

  void like()    => _triggerLike?.call();
  void dislike() => _triggerDislike?.call();
  void shuffle() => _triggerShuffle?.call();
}