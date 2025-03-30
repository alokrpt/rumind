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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Filter Messages',
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Financial Messages Only'),
                value: _showFinancialOnly,
                activeColor: theme.primaryColor,
                onChanged: (value) {
                  setDialogState(() {
                    _showFinancialOnly = value;
                  });
                },
              ),
              if (_showFinancialOnly) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<TransactionType?>(
                  decoration: InputDecoration(
                    labelText: 'Transaction Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  decoration: InputDecoration(
                    labelText: 'Sender',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              child: Text(
                'CLEAR',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_showFinancialOnly) {
                  _applyFinancialFilters();
                } else {
                  _refreshMessages();
                }
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('APPLY'),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          _showFinancialOnly ? 'Financial Messages' : 'SMS Messages',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter messages',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh messages',
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
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Loading messages...',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any SMS messages in your inbox',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Messages'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _refreshMessages,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFinancialState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any financial messages in your inbox',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _refreshMessages,
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.message),
                  label: const Text('View All Messages'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor),
                  ),
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
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
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
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final transaction = _financialTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildMessageCard(SmsMessage message) {
    final theme = Theme.of(context);

    // Format the date directly from DateTime object
    String formattedDate = 'Unknown';
    if (message.date != null) {
      final date = message.date;
      formattedDate = '${date?.day}/${date?.month}/${date?.year} ${date?.hour}:${date?.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.message,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message.address ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Text(
                message.body ?? 'No content',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(FinancialTransaction transaction) {
    final theme = Theme.of(context);

    // Format the date directly from the original message's DateTime
    String formattedDate = 'Unknown';
    if (transaction.originalMessage.date != null) {
      final date = transaction.originalMessage.date;
      formattedDate = '${date?.day}/${date?.month}/${date?.year} ${date?.hour}:${date?.minute.toString().padLeft(2, '0')}';
    }

    final typeColor = _getTypeColor(transaction.type).withOpacity(0.9);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: typeColor.withOpacity(0.2),
                        child: Icon(
                          _getTransactionIcon(transaction.type),
                          size: 16,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          transaction.originalMessage.address ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTransactionType(transaction.type),
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (transaction.amount != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.currency_rupee,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${transaction.amount}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (transaction.merchant != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.storefront,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transaction.merchant!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                transaction.originalMessage.body ?? 'No content',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.creditCard:
        return Icons.credit_card;
      case TransactionType.debit:
        return Icons.money_off;
      case TransactionType.upi:
        return Icons.mobile_friendly;
      case TransactionType.recharge:
        return Icons.phone_android;
      case TransactionType.statement:
        return Icons.receipt_long;
      case TransactionType.balance:
        return Icons.account_balance_wallet;
      case TransactionType.other:
        return Icons.paid;
    }
  }
}
