import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../enums/language_code.dart';

/// Speech-to-text service wrapping [SpeechToText].
///
/// Exposes reactive [isListening] and [liveText] so the UI can show a live
/// listening overlay with real-time transcript.
/// [listen] starts recognition and returns the final recognised string, or
/// `null` if recognition is unavailable or produces no result.
class SttService extends GetxService {
  final SpeechToText _stt = SpeechToText();

  /// `true` while the microphone is actively listening.
  final RxBool isListening = false.obs;

  /// Live partial transcript updated in real time during listening.
  final RxString liveText = ''.obs;

  bool _initialized = false;

  @override
  Future<void> onInit() async {
    super.onInit();
    // macOS desktop TCC crashes at OS level before Dart try-catch can run —
    // skip initialization there. Use a real Android/iOS device for STT.
    if (defaultTargetPlatform == TargetPlatform.macOS) return;
    try {
      _initialized = await _stt.initialize(
        onError: (e) {
          isListening.value = false;
          liveText.value = '';
        },
        onStatus: (status) {
          // Any status other than 'listening' means the session has ended.
          if (status != 'listening') {
            isListening.value = false;
          }
        },
        debugLogging: false,
      );
    } catch (_) {
      // STT unavailable on this platform/device — mic button will be disabled.
      _initialized = false;
    }
  }

  /// Starts listening in the locale matching [language] and returns the
  /// recognised text when the user stops speaking, or `null` on failure.
  /// Times out after [timeout] if no result arrives (e.g. on iOS Simulator).
  /// [pauseMs] controls how long to wait after silence before stopping.
  Future<String?> listen(LanguageCode language,
      {int pauseMs = 2000,
      Duration timeout = const Duration(seconds: 30)}) async {
    if (!_initialized || isListening.value) return null;

    String? result;
    liveText.value = '';
    isListening.value = true;

    try {
      // Use `confirmation` mode — universally supported across Android OEMs
      // (including Samsung). `dictation` mode crashes on some devices.
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          pauseFor: Duration(milliseconds: pauseMs),
          localeId: _locale(language),
          cancelOnError: true,
        ),
        onResult: (r) {
          try {
            if (r.recognizedWords.isNotEmpty) {
              result = r.recognizedWords;
              liveText.value = r.recognizedWords;
            }
          } catch (_) {
            // Guard against rare callback-on-disposed-widget errors.
          }
        },
      );
    } catch (e) {
      isListening.value = false;
      liveText.value = '';
      return null;
    }

    // Wait until listening stops (status handler sets isListening=false) or timeout.
    final deadline = DateTime.now().add(timeout);
    while (isListening.value && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (isListening.value) {
      try {
        await _stt.stop();
      } catch (_) {}
      isListening.value = false;
    }
    liveText.value = '';

    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  /// Stops listening immediately.
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    isListening.value = false;
    liveText.value = '';
  }

  /// Returns `true` if speech recognition is available on this device.
  bool get isAvailable => _initialized;

  @override
  void onClose() {
    _stt.stop();
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

/// Compares [recognised] against [expected] with fuzzy tolerance.
///
/// Normalises both strings (lowercase, strip punctuation) then checks
/// that at least [threshold] fraction of expected words appear in the
/// recognised text. A threshold of 0.75 means 75% of words must match.
bool sttMatches(String recognised, String expected, {double threshold = 0.75}) {
  String normalise(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s]", unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final r = normalise(recognised);
  final e = normalise(expected);

  if (r.isEmpty || e.isEmpty) return false;
  if (r == e) return true;

  final expectedWords = e.split(' ').where((w) => w.isNotEmpty).toList();
  if (expectedWords.isEmpty) return false;

  final recognisedWords = r.split(' ').toSet();
  final matchCount =
      expectedWords.where((w) => recognisedWords.contains(w)).length;

  return matchCount / expectedWords.length >= threshold;
}
