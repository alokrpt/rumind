import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
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
      text: "Connecting to ${AppConstants.appName}...",
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
              text: "Hello! I'm ${AppConstants.appName}, your financial AI assistant. How can I help you today?",
              isUser: false,
            ));
          }
        } else {
          _messages.add(ChatMessage(
            text: "Error connecting to ${AppConstants.appName}. Please check your API key configuration in app_constants.dart.",
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
            text: "Error connecting to ${AppConstants.appName}: ${e.toString()}",
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

    // Get response from API
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

      // Get response from API
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.7),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: _messages.isEmpty ? _buildEmptyState(context) : _buildChatList(context),
              ),
              _buildLoadingIndicator(context),
              _buildInputBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _testConnection,
              tooltip: 'Test connection',
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Start a conversation with ${AppConstants.appName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Ask questions about your finances, spending habits, or get budgeting advice',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    return ListView.builder(
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
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    if (!_isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${AppConstants.appName} is thinking...',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promptController,
              decoration: InputDecoration(
                hintText: _isConnectionWorking ? 'Ask ${AppConstants.appName} about your finances...' : 'Connection error. Try refreshing...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                ),
              ),
              enabled: _isConnectionWorking && !_isLoading,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isConnectionWorking && !_isLoading ? _sendMessage : null,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(context, isUser: false),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isUser ? Alignment.topRight : Alignment.topLeft,
                  end: isUser ? Alignment.bottomLeft : Alignment.bottomRight,
                  colors: isUser
                      ? [
                          theme.colorScheme.primary.withOpacity(0.8),
                          theme.colorScheme.primary.withOpacity(0.6),
                        ]
                      : [
                          Colors.white,
                          Colors.white.withOpacity(0.9),
                        ],
                ),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : null,
                  bottomLeft: !isUser ? const Radius.circular(0) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(context, isUser: true),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, {required bool isUser}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUser
              ? [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ]
              : [
                  Colors.purple,
                  Colors.blue,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.transparent,
        child: Icon(
          isUser ? Icons.person : Icons.psychology,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
