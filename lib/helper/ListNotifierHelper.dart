import 'package:flutter/foundation.dart';

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
