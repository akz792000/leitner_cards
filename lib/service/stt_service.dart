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

  /// Estimates a comfortable reading duration for [text] in seconds.
  ///
  /// Uses ~120 words-per-minute (2 wps) as a baseline — slower than natural
  /// speech to give the learner breathing room. Returns at least [minSeconds].
  static int _estimateReadingSeconds(String text, {int minSeconds = 5}) {
    final wordCount =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    // ~2 words per second → 0.5 s/word, rounded up.
    final estimated = (wordCount * 0.5).ceil();
    return estimated < minSeconds ? minSeconds : estimated;
  }

  /// Starts listening in the locale matching [language] and returns the
  /// recognised text when the user stops speaking, or `null` on failure.
  ///
  /// When [expectedText] is provided the pause and timeout are scaled to give
  /// the learner enough time to read the full sentence:
  /// * **pauseMs** — the larger of [pauseMs] (from settings) and a value
  ///   derived from the expected word count. This is the STT engine's own
  ///   silence-after-speech timeout.
  /// * **timeout** — the larger of [timeout] and the estimated reading time
  ///   plus a generous buffer. This is the hard deadline for the entire
  ///   listen session.
  ///
  /// [stabilityMs] controls how long the transcript must stay unchanged before
  /// it is considered final.
  Future<String?> listen(LanguageCode language,
      {int pauseMs = 2000,
      int stabilityMs = 800,
      Duration timeout = const Duration(seconds: 30),
      String? expectedText}) async {
    // Scale pause & timeout to text length so longer sentences get more time.
    if (expectedText != null && expectedText.isNotEmpty) {
      final readingSecs = _estimateReadingSeconds(expectedText);
      // Pause: at least 1 s per 5 words, minimum is the user's setting.
      final textPauseMs = (readingSecs * 400).clamp(pauseMs, 10000);
      pauseMs = textPauseMs;
      // Timeout: reading time + 50 % buffer, minimum is the caller's value.
      final textTimeout = Duration(seconds: (readingSecs * 1.5).ceil());
      if (textTimeout > timeout) timeout = textTimeout;
    }
    if (!_initialized || isListening.value) return null;

    String? result;
    bool acceptingResults = true;
    // Reset liveText here so any leftover text from the previous card doesn't
    // seed a false stability trigger at the start of the new listen session.
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
            if (acceptingResults && r.recognizedWords.isNotEmpty) {
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

    // Wait until listening stops, speech stabilises, or timeout expires.
    // stableSince resets whenever liveText changes, so each new card starts
    // with a clean slate (liveText is '' at the top of this method).
    final deadline = DateTime.now().add(timeout);
    String lastCheckedText = '';
    DateTime? stableSince;

    while (isListening.value && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));

      final current = liveText.value;
      if (current != lastCheckedText) {
        // New words arrived — reset stability timer.
        lastCheckedText = current;
        stableSince = null;
      } else if (current.isNotEmpty) {
        // Text unchanged — start/extend stability window.
        stableSince ??= DateTime.now();
        if (DateTime.now().difference(stableSince) >=
            Duration(milliseconds: stabilityMs)) {
          // Speech stable for [stabilityMs] — lock result before stop() fires
          // a final onResult that could replace the transcript.
          acceptingResults = false;
          final locked = result;
          try {
            await _stt.stop();
          } catch (_) {}
          result = locked;
          isListening.value = false;
          break;
        }
      }
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
/// Normalises both strings (lowercase, strip punctuation) then:
/// Returns true when [recognised] text is close enough to [expected].
///
/// Two modes:
/// 1. [containsMode] = true (default in settings): the expected phrase must
///    appear as a **contiguous sequence** inside recognised — extra words
///    before/after are fine, but inserted words or wrong order are not.
///    "i am ali and" passes for "i am ali" ✅; "i am a ali" does not ❌.
/// 2. [containsMode] = false: fuzzy — at least [threshold] fraction of
///    expected words must appear in recognised (default 75%).
bool sttMatches(
  String recognised,
  String expected, {
  double threshold = 0.75,
  bool containsMode = false,
}) {
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

  if (containsMode) {
    // Recognised must contain the expected phrase as a contiguous sequence.
    // Extra words before/after are fine; inserted words or wrong order are not.
    return r.contains(e);
  }

  // Fuzzy threshold: at least [threshold] fraction of expected words present.
  final matchCount =
      expectedWords.where((w) => recognisedWords.contains(w)).length;
  return matchCount / expectedWords.length >= threshold;
}
