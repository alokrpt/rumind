import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class AiService {
  static AiService? _instance;
  final Gemini _gemini = Gemini.instance;
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
  Future<void> initialize({required String apiKey}) async {
    if (_isInitialized) return;

    try {
      Gemini.init(apiKey: apiKey);
      _isInitialized = true;
      debugPrint('AI Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AI Service: $e');
      rethrow;
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Send a text prompt to Gemini and get a response
  Future<String?> sendTextPrompt(String prompt) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      final response = await _gemini.text(prompt);
      return response?.output;
    } catch (e) {
      debugPrint('Error sending text prompt: $e');
      rethrow;
    }
  }

  /// Send a prompt with parts (text, images, etc.) to Gemini and get a response
  Future<String?> sendPrompt({required List<Part> parts}) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      final response = await _gemini.prompt(parts: parts);
      return response?.output;
    } catch (e) {
      debugPrint('Error sending prompt: $e');
      rethrow;
    }
  }

  /// Stream a prompt to Gemini and get responses as they're generated
  Stream<String?> streamPrompt({required List<Part> parts}) {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      return _gemini.promptStream(parts: parts).map((response) => response?.output);
    } catch (e) {
      debugPrint('Error streaming prompt: $e');
      rethrow;
    }
  }

  /// Start or continue a chat conversation with Gemini
  Future<String?> chat(List<Content> conversation) async {
    if (!_isInitialized) {
      throw Exception('AI Service not initialized. Call initialize() first.');
    }

    try {
      final response = await _gemini.chat(conversation);
      return response?.output;
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
      final response = await _gemini.text(prompt);
      return response?.output;
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
      final response = await _gemini.text(prompt);
      return response?.output;
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
      final response = await _gemini.text(prompt);
      return response?.output;
    } catch (e) {
      debugPrint('Error generating financial insights: $e');
      rethrow;
    }
  }
}
