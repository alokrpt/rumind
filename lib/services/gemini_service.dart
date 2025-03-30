import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/api_keys.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.0-flash';
  late final GenerativeModel _model;
  bool _isInitialized = false;

  // Singleton pattern
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  GeminiService._internal() {
    _initModel();
  }

  void _initModel() {
    try {
      final apiKey = ApiKeys.geminiApiKey;

      // Debug log for the API key
      final keyPreview =
          apiKey.isNotEmpty ? '${apiKey.substring(0, min(4, apiKey.length))}...${apiKey.substring(max(0, apiKey.length - 4))}' : 'empty';
      debugPrint('GeminiService initializing with API key: $keyPreview (length: ${apiKey.length})');

      if (!ApiKeys.isValidGeminiApiKey(apiKey)) {
        debugPrint('⚠️ WARNING: API key does not match expected format. Check in app_constants.dart');
      }

      _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey.trim(),
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing GeminiService: $e');
      _isInitialized = false;
    }
  }

  // Helper methods for min/max
  int min(int a, int b) => a < b ? a : b;
  int max(int a, int b) => a > b ? a : b;

  /// Generates text based on a prompt
  Future<String> generateText(String prompt) async {
    if (!_isInitialized) {
      _initModel(); // Try to initialize again
      if (!_isInitialized) {
        return 'Error: GeminiService not properly initialized. Check API key configuration.';
      }
    }

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'No response generated';
    } catch (e) {
      debugPrint('Error in generateText: $e');
      return 'Error: ${e.toString()}';
    }
  }

  /// Generates text with streaming response
  Stream<String> streamGenerateText(String prompt) async* {
    if (!_isInitialized) {
      _initModel(); // Try to initialize again
      if (!_isInitialized) {
        yield 'Error: GeminiService not properly initialized. Check API key configuration.';
        return;
      }
    }

    try {
      final content = [Content.text(prompt)];
      final response = _model.generateContentStream(content);

      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      debugPrint('Error in streamGenerateText: $e');
      yield 'Error: ${e.toString()}';
    }
  }

  /// Multimodal prompt - text and images
  Future<String> generateFromImage(String prompt, Uint8List imageBytes) async {
    if (!_isInitialized) {
      _initModel(); // Try to initialize again
      if (!_isInitialized) {
        return 'Error: GeminiService not properly initialized. Check API key configuration.';
      }
    }

    try {
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'No response generated';
    } catch (e) {
      debugPrint('Error in generateFromImage: $e');
      return 'Error: ${e.toString()}';
    }
  }

  /// Creates a chat session
  ChatSession? startChat({
    List<Content>? history,
    GenerationConfig? generationConfig,
    List<SafetySetting>? safetySettings,
  }) {
    if (!_isInitialized) {
      _initModel(); // Try to initialize again
      if (!_isInitialized) {
        debugPrint('Error: GeminiService not properly initialized. Check API key configuration.');
        return null;
      }
    }

    try {
      return _model.startChat(
        history: history,
        generationConfig: generationConfig,
        safetySettings: safetySettings,
      );
    } catch (e) {
      debugPrint('Error in startChat: $e');
      return null;
    }
  }

  /// Test the API key with a direct HTTP request
  Future<bool> testApiConnection() async {
    try {
      final result = await generateText('Hello, this is a test message.');
      return !result.contains('Error');
    } catch (e) {
      debugPrint('Error testing API connection: $e');
      return false;
    }
  }

  /// Generate monthly transaction insights for line graphs
  Future<String> generateMonthlyInsights(List<String> transactions) async {
    if (!_isInitialized) {
      _initModel();
      if (!_isInitialized) {
        return 'Error: GeminiService not properly initialized';
      }
    }

    try {
      // Use a more concise format with clear instructions
      final prompt = '''
      Given these financial transactions, create monthly spending data with this format:
      [
        {"month": "Jan-2023", "total_spent": 1245.67, "income": 3000.00, "savings": 1754.33},
        {"month": "Feb-2023", "total_spent": 1398.21, "income": 3000.00, "savings": 1601.79}
      ]
      
      TRANSACTIONS:
      ${transactions.join("\n")}
      
      Respond ONLY with the JSON array. No other text.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return _cleanJsonResponse(response.text);
    } catch (e) {
      debugPrint('Error generating monthly insights: $e');
      return '[]';
    }
  }

  /// Generate category-based transaction insights for bar graphs
  Future<String> generateCategoryInsights(List<String> transactions) async {
    if (!_isInitialized) {
      _initModel();
      if (!_isInitialized) {
        return 'Error: GeminiService not properly initialized';
      }
    }

    try {
      // Use a more concise format with clear instructions
      final prompt = '''
      Categorize these financial transactions into 5-8 categories (like Food, Transport, etc).
      Format as JSON array:
      [
        {"category": "Food", "amount": 350.25, "percentage": 28.1},
        {"category": "Transport", "amount": 210.75, "percentage": 16.9}
      ]
      
      TRANSACTIONS:
      ${transactions.join("\n")}
      
      Respond ONLY with the JSON array. No other text.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return _cleanJsonResponse(response.text);
    } catch (e) {
      debugPrint('Error generating category insights: $e');
      return '[]';
    }
  }

  /// Generate recurring payment insights with forecasts
  Future<String> generateRecurringPaymentInsights(List<String> transactions) async {
    if (!_isInitialized) {
      _initModel();
      if (!_isInitialized) {
        return 'Error: GeminiService not properly initialized';
      }
    }

    try {
      // Improved prompt with clearer instructions and detection criteria
      final prompt = '''
      Analyze these financial transactions to identify recurring payments with these exact criteria:

      1. DEFINITION: A recurring payment is a transaction that occurs regularly (monthly, weekly, quarterly, etc.) with the same payee and approximately the same amount.
      
      2. IDENTIFICATION RULES:
         - Look for identical or very similar transaction descriptions
         - Look for consistent payment amounts or amounts with minor variations (<5%)
         - Look for consistent time intervals (around 28-31 days for monthly payments)
         - Common indicators include: subscription, emi, payment, bill, standing instruction
         - Ignore one-time transactions like refunds, cashbacks, or unique purchases
      
      3. FORMAT: Return ONLY a JSON array in this exact format:
      [
        {"payee": "Netflix", "amount": 14.99, "frequency": "monthly", "last_payment": "2023-07-15", "next_payment": "2023-08-15"},
        {"payee": "Gym", "amount": 39.99, "frequency": "monthly", "last_payment": "2023-07-05", "next_payment": "2023-08-05"}
      ]
      
      4. For each recurring payment:
         - "payee": Extract the merchant/payee name (simplify if needed)
         - "amount": Use the most recent transaction amount
         - "frequency": Determine based on time patterns ("monthly", "weekly", "quarterly", etc.)
         - "last_payment": Use the date of the most recent transaction
         - "next_payment": Predict the next payment date based on the frequency
      
      5. If the next payment date cannot be determined, use "null"
      
      TRANSACTIONS:
      ${transactions.join("\n")}
      
      Return ONLY the JSON array - no explanation, no extra text.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return _cleanJsonResponse(response.text);
    } catch (e) {
      debugPrint('Error generating recurring payment insights: $e');
      return '[]';
    }
  }

  /// Cleans response text by removing markdown code block delimiters
  String _cleanJsonResponse(String? responseText) {
    return responseText?.trim().replaceAll('```json', '').replaceAll('```', '') ?? '';
  }

  /// Generate comprehensive financial insights in parallel for better performance
  Future<Map<String, dynamic>> generateFinancialInsights(List<String> transactions) async {
    final results = <String, dynamic>{};

    try {
      // Run all three analyses in parallel for faster response
      final futures = await Future.wait(
          [generateMonthlyInsights(transactions), generateCategoryInsights(transactions), generateRecurringPaymentInsights(transactions)]);

      // Process results
      try {
        results['monthly'] = jsonDecode(futures[0]);
      } catch (e) {
        debugPrint('Error parsing monthly JSON: $e');
        results['monthly'] = [];
      }

      try {
        results['categories'] = jsonDecode(futures[1]);
      } catch (e) {
        debugPrint('Error parsing categories JSON: $e');
        results['categories'] = [];
      }

      try {
        results['recurring'] = jsonDecode(futures[2]);
      } catch (e) {
        debugPrint('Error parsing recurring JSON: $e');
        results['recurring'] = [];
      }

      return results;
    } catch (e) {
      debugPrint('Error generating financial insights: $e');
      return {'error': e.toString(), 'monthly': [], 'categories': [], 'recurring': []};
    }
  }

  /// Save JSON data to files in the app's documents directory
  Future<Map<String, String>> _saveJsonFiles(Map<String, dynamic> jsonData) async {
    final paths = <String, String>{};

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final entry in jsonData.entries) {
        if (entry.value is List) {
          final filename = 'financial_insights_${entry.key}_$timestamp.json';
          final file = File('${directory.path}/$filename');
          await file.writeAsString(jsonEncode(entry.value));
          paths[entry.key] = file.path;
        }
      }

      return paths;
    } catch (e) {
      debugPrint('Error saving JSON files: $e');
      return {};
    }
  }
}
