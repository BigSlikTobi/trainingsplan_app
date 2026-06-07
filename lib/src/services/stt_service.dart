import 'package:speech_to_text/speech_to_text.dart';

import '../util/app_log.dart';

/// On-device speech-to-text for dictating chat messages, wrapping Apple's
/// `SFSpeechRecognizer` (and iOS 26 `SpeechAnalyzer` where available) via the
/// `speech_to_text` plugin. No network, no cloud — recognition stays on the
/// device where the platform supports it.
///
/// iOS requires `NSMicrophoneUsageDescription` and
/// `NSSpeechRecognitionUsageDescription` in Info.plist; the first
/// [ensureInitialized] call triggers the permission prompts.
class SttService {
  SttService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _available = false;

  /// Invoked with true/false as the recogniser starts and stops listening
  /// (including auto-stop on silence), so the UI can mirror the mic state.
  void Function(bool listening)? onListeningChanged;

  bool get isListening => _speech.isListening;

  Future<bool> ensureInitialized() async {
    if (_initialized) return _available;
    try {
      _available = await _speech.initialize(
        onError: (error) => AppLog.warn('STT error: ${error.errorMsg}'),
        onStatus: (status) =>
            onListeningChanged?.call(status == SpeechToText.listeningStatus),
      );
    } on Object catch (error, stackTrace) {
      AppLog.warn('STT init failed', error: error, stackTrace: stackTrace);
      _available = false;
    }
    _initialized = true;
    return _available;
  }

  /// Starts listening and streams partial + final transcripts to [onResult].
  /// Returns false when recognition is unavailable or permission was denied.
  Future<bool> start({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!await ensureInitialized()) return false;
    try {
      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: localeId,
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } on Object catch (error, stackTrace) {
      AppLog.warn('STT listen failed', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> stop() async {
    try {
      if (_speech.isListening) await _speech.stop();
    } on Object catch (error, stackTrace) {
      AppLog.warn('STT stop failed', error: error, stackTrace: stackTrace);
    }
  }
}
