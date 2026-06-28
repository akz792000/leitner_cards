import 'package:flutter/widgets.dart';

/// Navigation wrapper that exposes a [navigatorKey] and [routeObserver] for
/// imperative routing and route-aware state refreshes.
///
/// GetX's `Get.toNamed` can conflict with a custom [navigatorKey], so all
/// screen transitions go through this service to stay consistent. The key is
/// registered in [MaterialApp.navigatorKey] so it always targets the root navigator.
/// [routeObserver] is registered in [MaterialApp.navigatorObservers] and used by
/// screens that need to refresh when they re-enter the foreground (e.g. LevelScreen).
class RouteService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Shared [RouteObserver] — subscribe in screens that need [didPopNext] callbacks.
  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

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
}
