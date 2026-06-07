import 'package:flutter_tts/flutter_tts.dart';

import '../util/app_log.dart';

/// On-device text-to-speech for the coach chat, wrapping Apple's
/// `AVSpeechSynthesizer` via `flutter_tts`. No network, no API key, works
/// offline — the coach's voice never leaves the phone.
///
/// The iOS audio session is configured to **duck** other audio (e.g. the
/// athlete's workout playlist): the music lowers while the coach speaks and
/// restores afterwards, routed to the speaker.
class TtsService {
  TtsService({FlutterTts? engine}) : _tts = engine ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } on Object catch (error, stackTrace) {
      AppLog.warn('TTS init failed', error: error, stackTrace: stackTrace);
    }
  }

  /// Speaks [text] in [languageTag] (e.g. `de-DE`, `en-US`), interrupting any
  /// utterance already in progress. Best-effort: failures are logged, not
  /// thrown, so a missing voice never breaks the chat.
  Future<void> speak(String text, {required String languageTag}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ensureReady();
    try {
      await _tts.stop();
      await _tts.setLanguage(languageTag);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.speak(trimmed);
    } on Object catch (error, stackTrace) {
      AppLog.warn('TTS speak failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (error, stackTrace) {
      AppLog.warn('TTS stop failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> dispose() => stop();
}
