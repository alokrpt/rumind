import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

/// Type of financial transaction detected in SMS
enum TransactionType { creditCard, debit, upi, recharge, statement, balance, other }

/// Simple model to represent a financial transaction from SMS
class FinancialTransaction {
  final SmsMessage originalMessage;
  final TransactionType type;
  final String? amount;
  final String? merchant;
  final String? date;

  FinancialTransaction({
    required this.originalMessage,
    required this.type,
    this.amount,
    this.merchant,
    this.date,
  });

  @override
  String toString() {
    return 'Transaction(type: $type, amount: $amount, merchant: $merchant)';
  }
}

class SmsService {
  final SmsQuery _query = SmsQuery();
  final _smsStreamController = StreamController<List<SmsMessage>>.broadcast();
  final _financialSmsController = StreamController<List<FinancialTransaction>>.broadcast();

  Stream<List<SmsMessage>> get smsStream => _smsStreamController.stream;
  Stream<List<FinancialTransaction>> get financialSmsStream => _financialSmsController.stream;
  bool _isInitialized = false;

  // Common financial keywords
  static final List<String> _financialKeywords = [
    'spent',
    'payment',
    'transaction',
    'credited',
    'debited',
    'paid',
    'received',
    'transfer',
    'balance',
    'upi',
    'bank',
    'credit card',
    'debit card',
    'statement',
    'bill',
    'due',
    'recharge',
    'successful'
  ];

  // Bank and payment service identifiers
  static final List<String> _financialSenders = [
    'sbi',
    'hdfc',
    'icici',
    'axis',
    'kotak',
    'pnb',
    'canara',
    'idbi',
    'paytm',
    'phonepe',
    'gpay',
    'google pay',
    'amazonpay',
    'amazon pay',
    'bhim',
    'airtel',
    'jio',
    'vodafone',
    'visa',
    'mastercard',
    'rupay',
    'billdesk'
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check and request permissions
      final permissionStatus = await Permission.sms.status;
      if (permissionStatus.isDenied) {
        debugPrint('SMS permission is denied');
      }

      // Load initial messages
      await refreshMessages();

      _isInitialized = true;
      debugPrint('SMS service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing SMS service: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.sms.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting SMS permission: $e');
      return false;
    }
  }

  Future<void> refreshMessages() async {
    try {
      // Check permission status first
      final permissionStatus = await Permission.sms.status;
      if (permissionStatus.isDenied) {
        debugPrint('SMS permission is denied, requesting it before refreshing');
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('SMS permission was not granted, cannot refresh messages');
          _smsStreamController.add([]);
          return;
        }
      }

      // Use getMessages with inbox filter instead of getAllSms
      final messages = await getMessages(kinds: [SmsQueryKind.inbox], count: 1000);

      _smsStreamController.add(messages);
      debugPrint('Loaded ${messages.length} SMS inbox messages');

      // Process financial messages
      final financialMessages = filterFinancialMessages(messages);
      _financialSmsController.add(financialMessages);
      debugPrint('Found ${financialMessages.length} financial transaction messages');
    } catch (e) {
      debugPrint('Error refreshing SMS messages: $e');
      _smsStreamController.add([]);
    }
  }

  Future<List<SmsMessage>> getMessages({
    String? address,
    List<SmsQueryKind> kinds = const [],
    int? count,
  }) async {
    try {
      final messages = await _query.querySms(
        sort: true,
        address: address,
        kinds: kinds,
        count: count,
      );
      for (var message in messages) {
        debugPrint('Sender: ${message.address}, Message: ${message.body}');
      }
      return messages;
    } catch (e) {
      debugPrint('Error getting SMS messages: $e');
      return [];
    }
  }

  /// Filter messages to find ones related to financial transactions
  List<FinancialTransaction> filterFinancialMessages(List<SmsMessage> messages) {
    final List<FinancialTransaction> financialTransactions = [];

    for (final message in messages) {
      final String body = message.body?.toLowerCase() ?? '';
      final String sender = message.address?.toLowerCase() ?? '';

      // Skip if empty body
      if (body.isEmpty) continue;

      // Check if this is likely a financial message
      bool isFinancial = false;

      // Check sender name
      for (final bankName in _financialSenders) {
        if (sender.contains(bankName)) {
          isFinancial = true;
          break;
        }
      }

      // Check for keywords in body if not already identified
      if (!isFinancial) {
        for (final keyword in _financialKeywords) {
          if (body.contains(keyword)) {
            isFinancial = true;
            break;
          }
        }
      }
      if (sender.contains('RZRPAY')) {
        // hide razorpay messages
        isFinancial = false;
      }

      if (isFinancial) {
        // Try to classify the transaction type
        TransactionType type = TransactionType.other;
        String? amount;
        String? merchant;

        // Extract transaction type
        if (body.contains('credit card') || body.contains('creditcard') || sender.contains('sbicrd')) {
          type = TransactionType.creditCard;
        } else if (body.contains('debit') || body.contains('debited')) {
          type = TransactionType.debit;
        } else if (body.contains('upi')) {
          type = TransactionType.upi;
        } else if (body.contains('recharge') || body.contains('recharged')) {
          type = TransactionType.recharge;
        } else if (body.contains('statement')) {
          type = TransactionType.statement;
        } else if (body.contains('balance')) {
          type = TransactionType.balance;
        }

        // Try to extract amount - look for patterns like Rs.1,234.56 or INR 1234.56
        RegExp amountRegex = RegExp(r'(?:rs\.?|inr)\s?([0-9,]+\.?[0-9]*)');
        final amountMatch = amountRegex.firstMatch(body);
        if (amountMatch != null) {
          amount = amountMatch.group(1)?.replaceAll(',', '');
        }

        // Try to extract merchant - often follows "at" or "to"
        RegExp merchantRegex = RegExp(r'(?:at|to)\s+([a-zA-Z0-9\s]+)');
        final merchantMatch = merchantRegex.firstMatch(body);
        if (merchantMatch != null) {
          merchant = merchantMatch.group(1)?.trim();
        }

        financialTransactions.add(FinancialTransaction(
          originalMessage: message,
          type: type,
          amount: amount,
          merchant: merchant,
          date: _extractDate(body),
        ));
      }
    }

    return financialTransactions;
  }

  /// Get financial messages with filtering options
  Future<List<FinancialTransaction>> getFinancialMessages({
    TransactionType? type,
    String? senderFilter,
    int? minAmount,
    int? maxAmount,
  }) async {
    // First get all messages
    final messages = await getMessages(kinds: [SmsQueryKind.inbox], count: 1000);

    // Find all financial transactions
    List<FinancialTransaction> transactions = filterFinancialMessages(messages);

    // Apply filters if specified
    if (type != null) {
      transactions = transactions.where((t) => t.type == type).toList();
    }

    if (senderFilter != null) {
      transactions = transactions.where((t) => t.originalMessage.address?.toLowerCase().contains(senderFilter.toLowerCase()) ?? false).toList();
    }

    if (minAmount != null || maxAmount != null) {
      transactions = transactions.where((t) {
        if (t.amount == null) return false;

        try {
          final amt = double.parse(t.amount!);
          if (minAmount != null && amt < minAmount) return false;
          if (maxAmount != null && amt > maxAmount) return false;
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return transactions;
  }

  /// Extract date from message body
  String? _extractDate(String body) {
    // Look for common date formats
    final dateRegex = RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}');
    final match = dateRegex.firstMatch(body);
    return match?.group(0);
  }

  void dispose() {
    _smsStreamController.close();
    _financialSmsController.close();
  }
}
