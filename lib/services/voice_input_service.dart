import 'package:speech_to_text/speech_to_text.dart';

/// Offline voice-to-text service powered by the local speech_to_text package.
/// Captures speech input directly on device without sending data online.
class VoiceInputService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  /// Initializes the speech recognition engine.
  Future<bool> initSpeech() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (e) {
      _isInitialized = false;
    }
    return _isInitialized;
  }

  /// Starts listening to device mic. Triggers callback on text recognized.
  Future<void> startListening({required Function(String) onResult}) async {
    final available = await initSpeech();
    if (available) {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    }
  }

  /// Stops current listening session.
  Future<void> stopListening() async {
    if (_isInitialized) {
      await _speechToText.stop();
    }
  }

  /// Returns true if currently listening.
  bool get isListening => _speechToText.isListening;
}
