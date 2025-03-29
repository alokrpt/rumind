import 'package:brain_train/constants/app_constants.dart';
import 'package:brain_train/services/ai_service.dart';
import 'package:flutter/material.dart';

class GeminiTestScreen extends StatefulWidget {
  const GeminiTestScreen({super.key});

  @override
  State<GeminiTestScreen> createState() => _GeminiTestScreenState();
}

class _GeminiTestScreenState extends State<GeminiTestScreen> {
  final TextEditingController _promptController = TextEditingController();
  final AiService _aiService = AiService.instance;
  final ScrollController _scrollController = ScrollController();

  bool _isInitialized = false;
  bool _isLoading = false;
  String _response = '';

  // Test SMS messages for demonstration
  final List<String> _testSmsMessages = [
    "Rs.80.00 spent on your SBI Credit Card ending with 8393 at NEERAJ KUMAR GUPTA on 15-03-25 via UPI (Ref No. 544064978620).",
    "Your UPI-Mandate for Rs.6200.00 is successfully created towards GOOGLE INDIA DIGITAL SERVICES PVT LTD from A/c No: XXXXXX0754.",
    "A link to track your Flipkart order for FORTUNE Products has been sent to you by 7084465699.",
    "Recharge of INR 199.00 is successful for your Airtel Mobile on 18-03-2025 04:45 PM, TransID :139908070."
  ];

  @override
  void initState() {
    super.initState();
    _initializeAiService();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAiService() async {
    setState(() {
      _isLoading = true;
      _response = 'Initializing AI service...';
    });

    try {
      await _aiService.initialize(apiKey: AppConstants.geminiApiKey);
      setState(() {
        _isInitialized = true;
        _response = 'AI Service initialized successfully with API key from constants';
      });
    } catch (e) {
      setState(() {
        _response = 'Error initializing AI Service: $e';
      });
      _showSnackBar('Error initializing AI Service: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendPrompt() async {
    if (!_isInitialized) {
      _showSnackBar('Please wait for the AI Service to initialize');
      return;
    }

    if (_promptController.text.isEmpty) {
      _showSnackBar('Please enter a prompt');
      return;
    }

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final response = await _aiService.sendTextPrompt(_promptController.text);
      setState(() {
        _response = response ?? 'No response';
      });
    } catch (e) {
      _showSnackBar('Error sending prompt: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _analyzeSmsMessage() async {
    if (!_isInitialized) {
      _showSnackBar('Please wait for the AI Service to initialize');
      return;
    }

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final randomIndex = DateTime.now().millisecondsSinceEpoch % _testSmsMessages.length;
      final smsMessage = _testSmsMessages[randomIndex];
      _promptController.text = smsMessage;

      final response = await _aiService.analyzeSmsMessage(smsMessage);
      setState(() {
        _response = 'SMS: $smsMessage\n\nANALYSIS:\n${response ?? 'No response'}';
      });
    } catch (e) {
      _showSnackBar('Error analyzing SMS: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _categorizeSmsMessages() async {
    if (!_isInitialized) {
      _showSnackBar('Please wait for the AI Service to initialize');
      return;
    }

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final response = await _aiService.categorizeSmsMessages(_testSmsMessages);
      setState(() {
        _response = 'CATEGORIZATION:\n${response ?? 'No response'}';
      });
    } catch (e) {
      _showSnackBar('Error categorizing SMS messages: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Enter your prompt',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isLoading ? _sendPrompt : null,
                    child: const Text('Send Prompt'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isLoading ? _analyzeSmsMessage : null,
                    child: const Text('Analyze SMS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isLoading ? _categorizeSmsMessages : null,
                    child: const Text('Categorize All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Response:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_response.isEmpty ? 'Loading...' : _response),
                        ],
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        child: Text(_response),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
