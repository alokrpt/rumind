import 'dart:async';

import 'package:brain_train/screens/insights_screen.dart';
import 'package:brain_train/services/sms_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SmsListScreen extends StatefulWidget {
  const SmsListScreen({super.key});

  @override
  State<SmsListScreen> createState() => _SmsListScreenState();
}

class _SmsListScreenState extends State<SmsListScreen> {
  final List<SmsMessage> _messages = [];
  final List<FinancialTransaction> _financialTransactions = [];
  bool _isLoading = true;
  bool _permissionsRequested = false;
  StreamSubscription<List<SmsMessage>>? _subscription;
  StreamSubscription<List<FinancialTransaction>>? _financialSubscription;

  // Filter state
  bool _showFinancialOnly = false;
  TransactionType? _selectedType;
  String? _selectedSender;

  @override
  void initState() {
    super.initState();
    _showFinancialOnly = true; // Set to show only financial transactions by default
    _initializeSmsService();
  }

  @override
  void dispose() {
    // Cancel the subscriptions when widget is disposed
    _subscription?.cancel();
    _financialSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSmsService() async {
    final smsService = context.read<SmsService>();
    await smsService.initialize();

    // Listen for new SMS messages
    _subscription = smsService.smsStream.listen(_handleSmsUpdate);

    // Listen for financial transactions
    _financialSubscription = smsService.financialSmsStream.listen(_handleFinancialUpdate);

    // Request SMS permissions if not already granted
    await _requestSmsPermissions();

    // Always explicitly refresh messages after setup regardless of permission state
    if (mounted) {
      await _refreshMessages();
    }
  }

  Future<void> _requestSmsPermissions() async {
    if (_permissionsRequested) return;

    _permissionsRequested = true;

    // Check current permission status
    var status = await Permission.sms.status;

    // Only show dialog if not already granted
    if (!status.isGranted) {
      // Only show dialog if the widget is still mounted
      if (!mounted) return;

      // Show a permission explanation dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text(
            'This app needs permission to read SMS messages for training purposes. '
            'Please grant the permission on the next screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Check if still mounted after dialog
      if (!mounted) return;

      // Request actual permission
      final smsService = context.read<SmsService>();
      await smsService.requestPermission();
    }

    // No need to refresh messages here since we'll do it in _initializeSmsService
  }

  void _handleSmsUpdate(List<SmsMessage> messages) {
    // Only update state if widget is still mounted
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  void _handleFinancialUpdate(List<FinancialTransaction> transactions) {
    // Only update state if widget is still mounted
    if (!mounted) return;

    setState(() {
      _financialTransactions.clear();
      _financialTransactions.addAll(transactions);
      _isLoading = false;
    });
  }

  Future<void> _refreshMessages() async {
    // Check if widget is still mounted
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final smsService = context.read<SmsService>();
    await smsService.refreshMessages();

    // Check again if widget is still mounted
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _applyFinancialFilters() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final smsService = context.read<SmsService>();
    final filteredTransactions = await smsService.getFinancialMessages(
      type: _selectedType,
      senderFilter: _selectedSender,
    );

    if (!mounted) return;

    setState(() {
      _financialTransactions.clear();
      _financialTransactions.addAll(filteredTransactions);
      _isLoading = false;
    });
  }

  void _toggleFinancialFilter() {
    setState(() {
      _showFinancialOnly = !_showFinancialOnly;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Messages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Financial Messages Only'),
                value: _showFinancialOnly,
                onChanged: (value) {
                  setDialogState(() {
                    _showFinancialOnly = value;
                  });
                },
              ),
              if (_showFinancialOnly) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<TransactionType?>(
                  decoration: const InputDecoration(
                    labelText: 'Transaction Type',
                  ),
                  value: _selectedType,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Types'),
                    ),
                    ...TransactionType.values.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_formatTransactionType(type)),
                        )),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Sender',
                  ),
                  value: _selectedSender,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Senders'),
                    ),
                    ..._getUniqueSenders().map((sender) => DropdownMenuItem(
                          value: sender,
                          child: Text(sender),
                        )),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedSender = value;
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _showFinancialOnly = false;
                  _selectedType = null;
                  _selectedSender = null;
                });
                _refreshMessages();
              },
              child: const Text('Clear Filters'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_showFinancialOnly) {
                  _applyFinancialFilters();
                } else {
                  _refreshMessages();
                }
                setState(() {});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getUniqueSenders() {
    final senders = _financialTransactions.map((t) => t.originalMessage.address ?? '').where((s) => s.isNotEmpty).toSet().toList();
    senders.sort();
    return senders;
  }

  String _formatTransactionType(TransactionType type) {
    switch (type) {
      case TransactionType.creditCard:
        return 'Credit Card';
      case TransactionType.debit:
        return 'Debit';
      case TransactionType.upi:
        return 'UPI';
      case TransactionType.recharge:
        return 'Recharge';
      case TransactionType.statement:
        return 'Statement';
      case TransactionType.balance:
        return 'Balance';
      case TransactionType.other:
        return 'Other';
    }
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.creditCard:
        return Colors.redAccent;
      case TransactionType.debit:
        return Colors.orange;
      case TransactionType.upi:
        return Colors.purple;
      case TransactionType.recharge:
        return Colors.green;
      case TransactionType.statement:
        return Colors.blue;
      case TransactionType.balance:
        return Colors.teal;
      case TransactionType.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showFinancialOnly ? 'Financial Messages' : 'SMS Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMessages,
          ),
        ],
      ),
      floatingActionButton: _financialTransactions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InsightsScreen(
                      transactions: _financialTransactions,
                    ),
                  ),
                );
              },
              tooltip: 'View Insights',
              label: const Text('View Insights'),
              icon: const Icon(Icons.insights),
            )
          : null,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading messages...'),
                ],
              ),
            )
          : _showFinancialOnly
              ? _financialTransactions.isEmpty
                  ? _buildEmptyFinancialState()
                  : _buildFinancialList()
              : _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No SMS messages found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any SMS messages in your inbox',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Messages'),
            onPressed: _refreshMessages,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFinancialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.currency_rupee,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No financial transactions found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any financial messages in your inbox',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: _refreshMessages,
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.message),
                label: const Text('View All Messages'),
                onPressed: () {
                  setState(() {
                    _showFinancialOnly = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageCard(message);
      },
    );
  }

  Widget _buildFinancialList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _financialTransactions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final transaction = _financialTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildMessageCard(SmsMessage message) {
    // Format the date more safely
    String formattedDate = 'Unknown';
    try {
      if (message.date != null) {
        final date = (message.date);
        formattedDate = date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : 'Unknown';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  message.address ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.body ?? 'No content',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(FinancialTransaction transaction) {
    // Format the date safely
    String formattedDate = 'Unknown';
    try {
      if (transaction.originalMessage.date != null) {
        final timestamp = int.tryParse(transaction.originalMessage.date.toString()) ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    transaction.originalMessage.address ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(transaction.type),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTransactionType(transaction.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (transaction.amount != null) ...[
              const SizedBox(height: 8),
              Text(
                'Amount: ₹${transaction.amount}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (transaction.merchant != null) ...[
              const SizedBox(height: 4),
              Text(
                'Merchant: ${transaction.merchant}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              transaction.originalMessage.body ?? 'No content',
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
