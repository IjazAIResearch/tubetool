class AppConfig {
  static const List<String> youtubeApiKeys = [
    'YOUR_YOUTUBE_API_KEY_1',
    'YOUR_YOUTUBE_API_KEY_2',
  ];

  static int _currentApiKeyIndex = 0;
  static final Map<String, bool> _exhaustedKeys = {};

  static String get youtubeApiKey => youtubeApiKeys[_currentApiKeyIndex];

  static bool hasAvailableKeys() {
    return _exhaustedKeys.length < youtubeApiKeys.length;
  }

  static void resetApiKeyStatus() {
    _exhaustedKeys.clear();
  }

  static void markKeyAsExhausted(String key) {
    _exhaustedKeys[key] = true;
  }

  static String? switchToNextApiKey() {
    if (!hasAvailableKeys()) {
      // All keys are exhausted
      resetApiKeyStatus(); // Reset all keys for the next day
      _currentApiKeyIndex = 0;
      return null;
    }

    // Find the next non-exhausted key
    int attempts = 0;
    do {
      _currentApiKeyIndex = (_currentApiKeyIndex + 1) % youtubeApiKeys.length;
      attempts++;
    } while (_exhaustedKeys[youtubeApiKey] == true &&
        attempts < youtubeApiKeys.length);

    return youtubeApiKey;
  }

  // Groq API configuration
  static const List<String> groqApiKeys = [
    'YOUR_GROQ_API_KEY_1',
    'YOUR_GROQ_API_KEY_2',
  ];

  static int _currentGroqKeyIndex = 0;
  static final Map<String, bool> _exhaustedGroqKeys = {};

  static String get groqApiKey => groqApiKeys[_currentGroqKeyIndex];

  static bool hasAvailableGroqKeys() {
    return _exhaustedGroqKeys.length < groqApiKeys.length;
  }

  static void resetGroqKeyStatus() {
    _exhaustedGroqKeys.clear();
  }

  static void markGroqKeyAsExhausted(String key) {
    _exhaustedGroqKeys[key] = true;
  }

  static String? switchToNextGroqKey() {
    if (!hasAvailableGroqKeys()) {
      // All keys are exhausted
      resetGroqKeyStatus(); // Reset all keys for the next day
      _currentGroqKeyIndex = 0;
      return null;
    }

    // Find the next non-exhausted key
    int attempts = 0;
    do {
      _currentGroqKeyIndex = (_currentGroqKeyIndex + 1) % groqApiKeys.length;
      attempts++;
    } while (_exhaustedGroqKeys[groqApiKey] == true &&
        attempts < groqApiKeys.length);

    return groqApiKey;
  }

  // Add other configuration values here
}
