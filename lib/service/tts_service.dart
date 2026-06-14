import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import '../enums/language_code.dart';
import '../service/settings_service.dart';

/// Text-to-speech service wrapping [FlutterTts].
///
/// Exposes reactive [isSpeaking], [wordStart] and [wordEnd] observables so the
/// UI can highlight the word currently being spoken in real time.
/// The progress handler fires on each word boundary — supported by the Google
/// TTS engine on Android; may be a no-op on Samsung TTS.
class TtsService extends GetxService {
  final FlutterTts _tts = FlutterTts();

  /// `true` while the TTS engine is actively speaking.
  final RxBool isSpeaking = false.obs;

  /// Character range of the word currently being spoken.
  final RxInt wordStart = 0.obs;
  final RxInt wordEnd = 0.obs;

  void _resetProgress() {
    wordStart.value = 0;
    wordEnd.value = 0;
  }

  @override
  void onInit() {
    super.onInit();
    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() {
      isSpeaking.value = false;
      _resetProgress();
    });
    _tts.setCancelHandler(() {
      isSpeaking.value = false;
      _resetProgress();
    });
    _tts.setErrorHandler((_) {
      isSpeaking.value = false;
      _resetProgress();
    });
    // Fires on each word boundary with the character start/end positions.
    _tts.setProgressHandler((text, start, end, word) {
      wordStart.value = start;
      wordEnd.value = end;
    });
    _tts.setSpeechRate(0.45); // slightly slower — better for language learning
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  /// Speaks [text] using the locale matching [language].
  /// Applies the current [SettingsService.speechRate] before each utterance.
  /// Returns `false` if the language engine is not installed on the device,
  /// `true` when playback starts successfully.
  Future<bool> speak(String text, LanguageCode language) async {
    if (text.isEmpty) return false;
    final locale = _locale(language);
    final available = await _tts.isLanguageAvailable(locale);
    if (available != true) return false;
    await _tts.setLanguage(locale);
    // Apply the user-configured speech rate on every speak call so changes
    // in SettingsService take effect immediately without restarting the service.
    await _tts.setSpeechRate(Get.find<SettingsService>().speechRate.value);
    await _tts.speak(text);
    return true;
  }

  /// Stops any active playback immediately.
  Future<void> stop() async {
    await _tts.stop();
    isSpeaking.value = false;
    _resetProgress();
  }

  @override
  void onClose() {
    _tts.stop();
    super.onClose();
  }

  String _locale(LanguageCode code) {
    switch (code) {
      case LanguageCode.en:
        return 'en-US';
      case LanguageCode.fa:
        return 'fa-IR';
      case LanguageCode.de:
        return 'de-DE';
    }
  }
}
