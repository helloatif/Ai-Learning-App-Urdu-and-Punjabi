import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class SpeechService {
  static final FlutterTts _flutterTts = FlutterTts();
  static final stt.SpeechToText _speechToText = stt.SpeechToText();
  static bool _isInitialized = false;
  static bool _isListening = false;
  static String _lastRecognizedText = '';

  /// Initialize speech services
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize TTS
      await _flutterTts.setLanguage('ur-PK'); // Urdu
      await _flutterTts.setSpeechRate(0.45); // Slower for learning
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Initialize STT
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          _isListening = status == 'listening';
        },
      );

      debugPrint('✓ Speech services initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('✗ Speech initialization error: $e');
      return false;
    }
  }

  /// Speak text in specified language
  static Future<void> speak(String text, String language) async {
    try {
      await _flutterTts.stop(); // Stop any ongoing speech

      // Set language
      String langCode = _getLanguageCode(language);
      await _flutterTts.setLanguage(langCode);

      // Adjust speech rate for learning
      await _flutterTts.setSpeechRate(0.4);

      debugPrint('Speaking ($language): $text');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  /// Start listening for speech input
  static Future<String> startListening(String language) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_speechToText.isAvailable) {
      debugPrint('Speech recognition not available');
      return '';
    }

    _lastRecognizedText = '';
    String localeId = _getLocaleId(language);

    await _speechToText.listen(
      onResult: (result) {
        _lastRecognizedText = result.recognizedWords;
        debugPrint('Recognized: $_lastRecognizedText');
      },
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );

    // Wait for listening to complete
    await Future.delayed(const Duration(seconds: 10));
    await stopListening();

    return _lastRecognizedText;
  }

  /// Stop listening
  static Future<void> stopListening() async {
    await _speechToText.stop();
    _isListening = false;
  }

  /// Stop speaking
  static Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  /// Check if currently listening
  static bool get isListening => _isListening;

  /// Get available locales
  static Future<List<String>> getAvailableLocales() async {
    if (!_isInitialized) await initialize();

    final locales = await _speechToText.locales();
    return locales.map((l) => '${l.name} (${l.localeId})').toList();
  }

  /// Set speech rate (0.0 - 1.0)
  static Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Set volume (0.0 - 1.0)
  static Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Get language code for TTS
  static String _getLanguageCode(String language) {
    switch (language.toLowerCase()) {
      case 'urdu':
        return 'ur-PK'; // Urdu (Pakistan)
      case 'punjabi':
        return 'pa-IN'; // Punjabi (fallback to Indian Punjabi)
      case 'english':
        return 'en-US';
      default:
        return 'ur-PK';
    }
  }

  /// Get locale ID for STT
  static String _getLocaleId(String language) {
    switch (language.toLowerCase()) {
      case 'urdu':
        return 'ur_PK';
      case 'punjabi':
        return 'pa_IN'; // Punjabi
      case 'english':
        return 'en_US';
      default:
        return 'ur_PK';
    }
  }
}
