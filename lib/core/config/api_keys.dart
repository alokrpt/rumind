import '../../constants/app_constants.dart';

class ApiKeys {
  // Use the actual API key from AppConstants
  static String get geminiApiKey => AppConstants.geminiApiKey;

  // Validate if the API key has the expected format
  static bool isValidGeminiApiKey(String apiKey) {
    // Most Gemini API keys start with "AIzaSy" and are ~39 characters long
    return apiKey.trim().startsWith('AIzaSy') && apiKey.trim().length >= 39 && apiKey.trim().length <= 42;
  }
}
