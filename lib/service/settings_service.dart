import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../enums/card_order.dart';

/// Persists all user-configurable settings to the Hive 'settings' box.
/// The box is opened by [ThemeService.init()] before this service initialises.
class SettingsService extends GetxService {
  late final Box _box;

  // STT keys
  static const _kMicEnabled = 'micEnabled';
  static const _kSttPauseMs = 'sttPauseMs'; // int, ms
  static const _kSttStabilityMs = 'sttStabilityMs'; // int, ms
  static const _kSttThreshold = 'sttThreshold'; // double 0.0–1.0
  static const _kContainsMode = 'containsMode'; // bool

  // TTS keys
  static const _kSpeakEnabled = 'speakEnabled';
  static const _kSpeechRate = 'speechRate'; // double 0.2–1.0
  static const _kAutoSpeak = 'autoSpeak';

  // Display keys
  static const _kCopyEnabled = 'copyEnabled';
  static const _kDescEnabled = 'descEnabled';
  static const _kCounterVisible = 'counterVisible';
  static const _kAmoledDim = 'amoledDim';
  static const _kDimDelayMin = 'dimDelayMin'; // int, minutes

  // Study keys
  static const _kCardOrder = 'cardOrder'; // int → CardOrder.code
  static const _kSubLevelOrder = 'subLevelOrder'; // int → CardOrder.code

  // Reactive fields — STT
  final RxBool micEnabled = true.obs;
  final RxInt sttPauseMs = 2000.obs;

  /// How long speech must stay unchanged before it is considered finalised.
  final RxInt sttStabilityMs = 800.obs;
  final RxDouble sttThreshold = 0.75.obs;

  /// When true, STT accepts the answer if the expected phrase appears anywhere
  /// inside what was said — extra words before/after are fine.
  final RxBool containsMode = true.obs;

  // Reactive fields — TTS
  final RxBool speakEnabled = true.obs;
  final RxDouble speechRate = 0.45.obs;
  final RxBool autoSpeak = false.obs;

  // Reactive fields — Display
  final RxBool copyEnabled = true.obs;
  final RxBool descEnabled = true.obs;
  final RxBool counterVisible = true.obs;
  final RxBool amoledDim = true.obs;
  final RxInt dimDelayMin = 2.obs;

  // Reactive fields — Study
  /// Primary ordering: which level group appears first.
  final Rx<CardOrder> cardOrder = CardOrder.highFirst.obs;

  /// Secondary ordering: within each level, which subLevel appears first.
  final Rx<CardOrder> subLevelOrder = CardOrder.highFirst.obs;

  /// Adds study time by raw code string (works for both legacy and UUID decks).
  void addStudyTimeByCode(String code, Duration elapsed) {
    if (elapsed.inSeconds < 1) return;
    final key = 'studyTime_$code';
    final current = _box.get(key, defaultValue: 0) as int;
    _box.put(key, current + elapsed.inSeconds);
  }

  @override
  void onInit() {
    super.onInit();
    _box = Hive.box('settings');
    _load();
    // Persist every change automatically.
    ever(micEnabled, (_) => _box.put(_kMicEnabled, micEnabled.value));
    ever(sttPauseMs, (_) => _box.put(_kSttPauseMs, sttPauseMs.value));
    ever(sttStabilityMs,
        (_) => _box.put(_kSttStabilityMs, sttStabilityMs.value));
    ever(sttThreshold, (_) => _box.put(_kSttThreshold, sttThreshold.value));
    ever(containsMode, (_) => _box.put(_kContainsMode, containsMode.value));
    ever(speakEnabled, (_) => _box.put(_kSpeakEnabled, speakEnabled.value));
    ever(speechRate, (_) => _box.put(_kSpeechRate, speechRate.value));
    ever(autoSpeak, (_) => _box.put(_kAutoSpeak, autoSpeak.value));
    ever(copyEnabled, (_) => _box.put(_kCopyEnabled, copyEnabled.value));
    ever(descEnabled, (_) => _box.put(_kDescEnabled, descEnabled.value));
    ever(counterVisible,
        (_) => _box.put(_kCounterVisible, counterVisible.value));
    ever(amoledDim, (_) => _box.put(_kAmoledDim, amoledDim.value));
    ever(dimDelayMin, (_) => _box.put(_kDimDelayMin, dimDelayMin.value));
    ever(cardOrder, (_) => _box.put(_kCardOrder, cardOrder.value.code));
    ever(subLevelOrder,
        (_) => _box.put(_kSubLevelOrder, subLevelOrder.value.code));
  }

  void _load() {
    micEnabled.value = _box.get(_kMicEnabled, defaultValue: true);
    sttPauseMs.value = _box.get(_kSttPauseMs, defaultValue: 2000);
    sttStabilityMs.value = _box.get(_kSttStabilityMs, defaultValue: 800);
    sttThreshold.value =
        (_box.get(_kSttThreshold, defaultValue: 0.75) as num).toDouble();
    containsMode.value = _box.get(_kContainsMode, defaultValue: true);
    speakEnabled.value = _box.get(_kSpeakEnabled, defaultValue: true);
    speechRate.value =
        (_box.get(_kSpeechRate, defaultValue: 0.45) as num).toDouble();
    autoSpeak.value = _box.get(_kAutoSpeak, defaultValue: false);
    copyEnabled.value = _box.get(_kCopyEnabled, defaultValue: true);
    descEnabled.value = _box.get(_kDescEnabled, defaultValue: true);
    counterVisible.value = _box.get(_kCounterVisible, defaultValue: true);
    amoledDim.value = _box.get(_kAmoledDim, defaultValue: true);
    dimDelayMin.value = _box.get(_kDimDelayMin, defaultValue: 2);
    cardOrder.value = CardOrder.fromCode(
        _box.get(_kCardOrder, defaultValue: CardOrder.highFirst.code));
    subLevelOrder.value = CardOrder.fromCode(
        _box.get(_kSubLevelOrder, defaultValue: CardOrder.highFirst.code));
  }

  /// Resets all settings to their default values.
  void resetToDefaults() {
    micEnabled.value = true;
    sttPauseMs.value = 2000;
    sttStabilityMs.value = 800;
    sttThreshold.value = 0.75;
    containsMode.value = true;
    speakEnabled.value = true;
    speechRate.value = 0.45;
    autoSpeak.value = false;
    copyEnabled.value = true;
    descEnabled.value = true;
    counterVisible.value = true;
    amoledDim.value = true;
    dimDelayMin.value = 2;
    cardOrder.value = CardOrder.highFirst;
    subLevelOrder.value = CardOrder.highFirst;
  }
}
