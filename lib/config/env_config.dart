/// Safe configuration for sensitive API keys and endpoints.
///
/// To use: Run flutter build/run with:
/// flutter run --dart-define=HUGGINGFACE_TOKEN=your_token_here
///
/// For production APK:
/// flutter build apk --dart-define=HUGGINGFACE_TOKEN=your_token_here
class EnvConfig {
  /// HuggingFace API token from environment variable
  /// Set via: flutter build apk --dart-define=HUGGINGFACE_TOKEN=xxx
  static const String huggingFaceToken = String.fromEnvironment(
    'HUGGINGFACE_TOKEN',
    defaultValue: '',
  );

  /// HuggingFace Model ID
  static const String huggingFaceModelId = 'RAFAY-484/Urdu-Punjabi-V2';

  /// HuggingFace Inference API URL
  static const String huggingFaceInferenceUrl =
      'https://api-inference.huggingface.co/models/RAFAY-484/Urdu-Punjabi-V2';

  /// Validate that required configuration is present
  static bool get isConfigured {
    return huggingFaceToken.isNotEmpty;
  }

  /// Get token or throw if not configured
  static String getHuggingFaceToken() {
    if (huggingFaceToken.isEmpty) {
      throw Exception(
        'HuggingFace API token not configured. '
        'Run: flutter run --dart-define=HUGGINGFACE_TOKEN=your_token_here',
      );
    }
    return huggingFaceToken;
  }
}
