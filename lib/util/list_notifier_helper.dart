import 'package:flutter/foundation.dart';

/// A [ValueNotifier] for lists that emits a change event on every mutation.
///
/// Standard [ValueNotifier<List>] does not fire listeners when you mutate
/// the list in-place. This wrapper always replaces the list reference so
/// [ValueListenableBuilder] rebuilds correctly.
class ListNotifierHelper<T> extends ValueNotifier<List<T>> {
  ListNotifierHelper(super.initialList);

  void add(T item) {
    final list = List.of(value)..add(item);
    value = list;
  }

  void remove(T item) {
    final list = List.of(value)..remove(item);
    value = list;
  }

  void clear() {
    final list = List<T>.empty(growable: true);
    value = list;
  }
}
