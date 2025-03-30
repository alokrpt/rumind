import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_keys.dart';

class AiService {
  static AiService? _instance;
  GenerativeModel? _model;
  bool _isInitialized = false;

  /// Private constructor for singleton pattern
  AiService._();

  /// Get the singleton instance
  static AiService get instance {
    _instance ??= AiService._();
    return _instance!;
  }

  /// Initialize the AI service with API key
  /// Must be called before using any other methods
  Future<void> initialize({String? apiKey}) async {
    if (_isInitialized) return;

    try {
      final apiKeyToUse = apiKey ?? ApiKeys.geminiApiKey;
      final trimmedKey = apiKeyToUse.trim();

      // Debug the API key (first 4 chars only for security)
      final keyPreview = trimmedKey.isNotEmpty ? '${trimmedKey.substring(0, min(4, trimmedKey.length))}...' : 'empty';
      debugPrint('Initializing with API key starting with: $keyPreview, length: ${trimmedKey.length}');

      // Validate API key format
      if (!ApiKeys.isValidGeminiApiKey(trimmedKey)) {
        debugPrint('WARNING: API key does not match expected format. Should start with "AIzaSy" and be ~39 characters.');
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: trimmedKey,
      );
      _isInitialized = true;
      debugPrint('AI Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AI Service: $e');
      rethrow;
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the model instance, with a check to make sure it's initialized
  GenerativeModel get _getModel {
    if (_model == null) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }
    return _model!;
  }

  /// Send a text prompt to Gemini and get a response
  Future<String?> sendTextPrompt(String prompt) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      final content = [Content.text(prompt)];
      final response = await _getModel.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Error sending text prompt: $e');
      rethrow;
    }
  }

  /// Send a prompt with parts (text, images, etc.) to Gemini and get a response
  Future<String?> sendPrompt({required String text, Uint8List? imageData}) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      Content content;
      if (imageData != null) {
        content = Content.multi([
          TextPart(text),
          DataPart('image/jpeg', imageData),
        ]);
      } else {
        content = Content.text(text);
      }

      final response = await _getModel.generateContent([content]);
      return response.text;
    } catch (e) {
      debugPrint('Error sending prompt: $e');
      rethrow;
    }
  }

  /// Stream a prompt to Gemini and get responses as they're generated
  Stream<String?> streamPrompt({required String text, Uint8List? imageData}) {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      Content content;
      if (imageData != null) {
        content = Content.multi([
          TextPart(text),
          DataPart('image/jpeg', imageData),
        ]);
      } else {
        content = Content.text(text);
      }

      return _getModel.generateContentStream([content]).map((response) => response.text);
    } catch (e) {
      debugPrint('Error streaming prompt: $e');
      rethrow;
    }
  }

  /// Chat session for conversations
  ChatSession? _chatSession;

  /// Start a new chat session
  void startNewChat() {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    _chatSession = _getModel.startChat();
  }

  /// Send a message in an existing chat session
  Future<String?> sendChatMessage(String message) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    if (_chatSession == null) {
      startNewChat();
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      return response.text;
    } catch (e) {
      debugPrint('Error in chat: $e');
      rethrow;
    }
  }

  /// Analyze an SMS message and provide insights
  Future<String?> analyzeSmsMessage(String message) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    final prompt = '''
    Analyze the following SMS message and provide insights:
    
    MESSAGE: $message
    
    Please provide:
    1. Is this a financial transaction? If yes, extract amount, merchant, date, and transaction type.
    2. Is this a promotional message? If yes, identify the brand and offer.
    3. Is this a security alert? If yes, summarize the alert.
    4. General summary of this message in 1-2 sentences.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _getModel.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Error analyzing SMS message: $e');
      rethrow;
    }
  }

  /// Categorize multiple SMS messages
  Future<String?> categorizeSmsMessages(List<String> messages) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    final messagesText = messages.map((msg) => "- $msg").join("\n");
    final prompt = '''
    Categorize the following SMS messages into categories like 
    Financial, Promotional, Security, Personal, etc.
    
    MESSAGES:
    $messagesText
    
    For each message, provide:
    1. Category
    2. Brief summary (1 sentence)
    3. Any important information extracted (amounts, dates, names)
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _getModel.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Error categorizing SMS messages: $e');
      rethrow;
    }
  }

  /// Generate insights from financial transactions
  Future<String?> generateFinancialInsights(List<String> transactions) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    final transactionsText = transactions.map((tx) => "- $tx").join("\n");
    final prompt = '''
    Analyze these financial transactions and provide insights:
    
    TRANSACTIONS:
    $transactionsText
    
    Please provide:
    1. Total spending by category
    2. Identify any unusual transactions
    3. Spending trends and patterns
    4. Budget recommendations
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _getModel.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Error generating financial insights: $e');
      rethrow;
    }
  }

  /// Test the API key with a direct HTTP request (bypassing the package)
  Future<bool> testApiKeyDirectly({String? apiKey}) async {
    final apiKeyToUse = apiKey ?? ApiKeys.geminiApiKey;

    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKeyToUse.trim()}';

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': 'Hello, testing the API key'}
            ]
          }
        ]
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('Direct API test status code: ${response.statusCode}');
      debugPrint('Direct API test response: ${response.body.substring(0, min(100, response.body.length))}...');

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error testing API key directly: $e');
      return false;
    }
  }

  // Helper function to get the minimum of two integers
  int min(int a, int b) => a < b ? a : b;
}
