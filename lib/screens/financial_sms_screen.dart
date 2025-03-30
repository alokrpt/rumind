import 'dart:async';

import 'package:brain_train/services/sms_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FinancialSmsScreen extends StatefulWidget {
  const FinancialSmsScreen({super.key});

  @override
  State<FinancialSmsScreen> createState() => _FinancialSmsScreenState();
}

class _FinancialSmsScreenState extends State<FinancialSmsScreen> {
  final List<FinancialTransaction> _transactions = [];
  bool _isLoading = true;
  TransactionType? _selectedType;
  String? _selectedSender;
  StreamSubscription<List<FinancialTransaction>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    final smsService = context.read<SmsService>();
    await smsService.initialize();

    // Listen for financial transactions
    _subscription = smsService.financialSmsStream.listen((transactions) {
      if (!mounted) return;

      setState(() {
        _transactions.clear();
        _transactions.addAll(transactions);
        _isLoading = false;
      });
    });

    // Refresh messages
    await _refreshMessages();
  }

  Future<void> _refreshMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final smsService = context.read<SmsService>();
    await smsService.refreshMessages();
  }

  Future<void> _applyFilter() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final smsService = context.read<SmsService>();
    final filteredTransactions = await smsService.getFinancialMessages(
      type: _selectedType,
      senderFilter: _selectedSender,
    );

    setState(() {
      _transactions.clear();
      _transactions.addAll(filteredTransactions);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Transactions'),
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading financial messages...'),
                ],
              ),
            )
          : _transactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Transactions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  setState(() {
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
                  setState(() {
                    _selectedSender = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
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
                _applyFilter();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getUniqueSenders() {
    final senders = _transactions.map((t) => t.originalMessage.address ?? '').where((s) => s.isNotEmpty).toSet().toList();
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

  Widget _buildEmptyState() {
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
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Messages'),
            onPressed: _refreshMessages,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionCard(transaction);
      },
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
