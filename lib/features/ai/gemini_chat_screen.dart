import 'package:flutter/material.dart';

import '../../services/gemini_service.dart';
import '../../services/sms_service.dart';

class GeminiChatScreen extends StatefulWidget {
  final List<FinancialTransaction>? transactions;
  final String? contextPrompt;

  const GeminiChatScreen({
    super.key,
    this.transactions,
    this.contextPrompt,
  });

  @override
  State<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends State<GeminiChatScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;
  bool _isConnectionTested = false;
  bool _isConnectionWorking = false;
  String? _financialContext;

  @override
  void initState() {
    super.initState();
    _financialContext = widget.contextPrompt;
    _testConnection();
    // _prepareFinancialContext();
  }

  void _prepareFinancialContext() {
    if (widget.transactions != null && widget.transactions!.isNotEmpty) {
      final contextPrompt = widget.contextPrompt ??
          "I'm showing you my financial transaction data. You can help analyze it and answer questions about my spending, income patterns, etc.";

      // Create a simplified context message based on transaction data
      final transactionSummary = widget.transactions!.take(20).map((t) {
        final amount = t.amount ?? 'N/A';
        final date = t.date ?? 'N/A';
        final merchant = t.merchant ?? 'Unknown';
        final type = t.type.toString().split('.').last;
        return '$date: $amount to $merchant ($type)';
      }).join('\n');

      _financialContext = '$contextPrompt\n\nHere are some of your recent transactions:\n$transactionSummary';

      // Add a special welcome message for financial context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isConnectionWorking) {
          setState(() {
            _messages.add(ChatMessage(
              text: "I have access to your financial transaction data. How can I help analyze your finances today?",
              isUser: false,
            ));
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
    });

    // Add a welcome message
    _messages.add(ChatMessage(
      text: "Testing connection to Gemini API...",
      isUser: false,
    ));

    try {
      final isWorking = await _geminiService.testApiConnection();

      setState(() {
        _isConnectionTested = true;
        _isConnectionWorking = isWorking;

        if (isWorking) {
          if (_financialContext != null) {
            _sendContext();
          } else {
            _messages.add(ChatMessage(
              text: "Connection successful! How can I help you today?",
              isUser: false,
            ));
          }
        } else {
          _messages.add(ChatMessage(
            text: "Error connecting to Gemini API. Please check your API key configuration in app_constants.dart.",
            isUser: false,
          ));
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnectionTested = true;
          _isConnectionWorking = false;
          _messages.add(ChatMessage(
            text: "Error connecting to AI API: ${e.toString()}",
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    }
  }

  void _sendContext() async {
    String prompt = "";
    if (_messages.where((m) => m.isUser).isEmpty && _financialContext != null) {
      prompt =
          "$_financialContext\n Analyze this report and summarize it in a few sentences also keep it in context for the user, then ask me if I want to know more about anything";
    }

    // Get response from Gemini
    if (prompt.isEmpty) {
      return;
    }

    try {
      final response = await _geminiService.generateText(prompt);

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Error: ${e.toString()}",
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  void _sendMessage() async {
    if (_promptController.text.trim().isEmpty) return;

    final userMessage = _promptController.text;
    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
      ));
      _isLoading = true;
      _promptController.clear();
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      // If this is the first user message and we have financial context, include it
      String prompt = userMessage;

      if (_messages.where((m) => m.isUser).isNotEmpty && _financialContext != null) {
        prompt = "use this context to answer the user's question: $_financialContext\n\n User question: $userMessage";
      }

      // Get response from Gemini
      final response = await _geminiService.generateText(prompt);

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
        ));
        _isLoading = false;
      });

      // Scroll to bottom again after getting response
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Error: ${e.toString()}",
          isUser: false,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Chat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testConnection,
            tooltip: 'Test connection',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation with Gemini!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return MessageBubble(
                        message: message.text,
                        isUser: message.isUser,
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: _isConnectionWorking ? 'Ask Gemini something...' : 'Connection error. Try refreshing...',
                      border: InputBorder.none,
                    ),
                    enabled: _isConnectionWorking && !_isLoading,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isConnectionWorking && !_isLoading ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            CircleAvatar(
              backgroundColor: Colors.blue.shade200,
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue.shade100 : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.black87 : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser)
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
