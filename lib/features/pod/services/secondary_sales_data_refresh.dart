import 'package:flutter/foundation.dart';

/// Lightweight invalidation signal for Secondary Sales screens.
///
/// After a successful statement-date update (or similar server-side change),
/// bump [tick] so dashboard / stockist statements / uploaded batches refetch
/// from Laravel instead of showing stale month groupings.
class SecondarySalesDataRefresh {
  SecondarySalesDataRefresh._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void notify() {
    tick.value = tick.value + 1;
  }
}
