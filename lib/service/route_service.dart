import 'package:flutter/widgets.dart';

/// Navigation wrapper that exposes a [navigatorKey] for imperative routing.
///
/// GetX's `Get.toNamed` can conflict with a custom [navigatorKey], so all
/// screen transitions go through this service to stay consistent. The key is
/// registered in [MaterialApp.navigatorKey] so it always targets the root navigator.
class RouteService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<T?> pushNamed<T extends Object?>(String routeName,
      {Object? arguments}) {
    final state = navigatorKey.currentState;
    if (state == null) return Future.value(null);
    return state.pushNamed<T>(routeName, arguments: arguments);
  }

  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
      String routeName,
      {Object? arguments,
      TO? result}) {
    final state = navigatorKey.currentState;
    if (state == null) return Future.value(null);
    return state.pushReplacementNamed<T, TO>(routeName,
        arguments: arguments, result: result);
  }

  void pop<T extends Object?>([T? result]) {
    navigatorKey.currentState?.pop(result);
  }

  bool canPop() {
    return navigatorKey.currentState?.canPop() ?? false;
  }
}
