import 'dart:async';

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
  bool _isLoading = true;
  bool _permissionsRequested = false;
  StreamSubscription<List<SmsMessage>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeSmsService();
  }

  @override
  void dispose() {
    // Cancel the subscription when widget is disposed
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSmsService() async {
    final smsService = context.read<SmsService>();
    await smsService.initialize();

    // Request SMS permissions if not already granted
    await _requestSmsPermissions();

    // Listen for new messages
    _subscription = smsService.smsStream.listen(_handleSmsUpdate);

    // Update loading state if still mounted
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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

    // Refresh messages after permissions if still mounted
    if (mounted) {
      await _refreshMessages();
    }
  }

  void _handleSmsUpdate(List<SmsMessage> messages) {
    // Only update state if widget is still mounted
    if (!mounted) return;

    setState(() {
      _messages.clear();

      // Sort messages by date (latest first)
      final sortedMessages = List<SmsMessage>.from(messages);
      sortedMessages.sort((a, b) {
        final dateA = int.tryParse(a.date?.toString() ?? '0') ?? 0;
        final dateB = int.tryParse(b.date?.toString() ?? '0') ?? 0;
        return dateB.compareTo(dateA); // Descending order (newest first)
      });

      _messages.addAll(sortedMessages);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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

  Widget _buildMessageCard(SmsMessage message) {
    // Format the date more safely
    String formattedDate = 'Unknown';
    try {
      if (message.date != null) {
        final timestamp = int.tryParse(message.date.toString()) ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        formattedDate = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
}
