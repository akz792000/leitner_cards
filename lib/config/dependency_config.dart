import 'package:get/get.dart';

import '../repository/card_repository.dart';
import '../repository/progress_repository.dart';
import '../service/auth_service.dart';
import '../service/card_service.dart';
import '../service/route_service.dart';
import '../service/settings_service.dart';
import '../service/study_log_service.dart';
import '../service/sync_service.dart';
import '../service/theme_service.dart';
import '../service/tts_service.dart';
import '../service/stt_service.dart';

/// Registers all GetX services and repositories in dependency order.
///
/// [AuthService] is registered first — the auth guard needs it before any
/// screen is rendered. [ThemeService] must precede [MyApp] because the widget
/// reads its mode synchronously. Repositories precede services that depend
/// on them.
class DependencyConfig {
  static Future registerDependencies() async {
    // 0. AuthService — Google Sign-In; needed by the auth guard.
    await Get.putAsync<AuthService>(() => AuthService.init());
    // 1. ThemeService — opens 'settings' Hive box; must be before MyApp.
    await Get.putAsync<ThemeService>(() => ThemeService.init());
    // 2. SettingsService — reads from the already-open 'settings' box.
    Get.put(SettingsService());
    // 3. RouteService — provides navigatorKey for MaterialApp.
    await Get.putAsync<RouteService>(() => Future.value(RouteService()));
    // 4–5. Repositories — open their respective Hive boxes.
    await Get.putAsync<CardRepository>(() => Future.value(CardRepository()));
    await Get.putAsync<ProgressRepository>(
        () => Future.value(ProgressRepository()));
    // 6. CardService — depends on both repositories.
    await Get.putAsync<CardService>(() => Future.value(CardService()));
    // 7. SyncService — depends on CardRepository.
    await Get.putAsync<SyncService>(() => Future.value(SyncService()));
    // 8. StudyLogService — opens 'studyLog' Hive box.
    await Get.putAsync<StudyLogService>(() => Future.value(StudyLogService()));
    // 9–10. Media services.
    await Get.putAsync<TtsService>(() => Future.value(TtsService()));
    await Get.putAsync<SttService>(() => Future.value(SttService()));
  }
}
