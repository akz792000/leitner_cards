import 'package:get/get.dart';

import '../repository/card_repository.dart';
import '../repository/progress_repository.dart';
import '../service/card_service.dart';
import '../service/route_service.dart';
import '../service/sync_service.dart';
import '../service/theme_service.dart';

/// Registers all GetX services and repositories in dependency order.
///
/// [ThemeService] must be first — [MyApp] reads its mode synchronously.
/// Repositories precede services that depend on them, and [SyncService]
/// comes last because it depends on all repositories.
class DependencyConfig {
  static Future registerDependencies() async {
    await Get.putAsync<ThemeService>(() => ThemeService.init());
    await Get.putAsync<RouteService>(() => Future.value(RouteService()));
    await Get.putAsync<CardRepository>(() => Future.value(CardRepository()));
    await Get.putAsync<ProgressRepository>(() => Future.value(ProgressRepository()));
    await Get.putAsync<CardService>(() => Future.value(CardService()));
    await Get.putAsync<SyncService>(() => Future.value(SyncService()));
  }
}
