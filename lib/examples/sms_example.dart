import 'dart:async';

import 'package:brain_train/services/sms_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:provider/provider.dart';

class SmsExample extends StatefulWidget {
  const SmsExample({super.key});

  @override
  State<SmsExample> createState() => _SmsExampleState();
}

class _SmsExampleState extends State<SmsExample> {
  final List<SmsMessage> _messages = [];
  bool _isLoading = true;
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
    // Get the SMS service from provider
    final smsService = context.read<SmsService>();

    // Initialize the service
    await smsService.initialize();

    // Listen for SMS messages first
    _subscription = smsService.smsStream.listen((messages) {
      // Check if widget is still mounted
      if (!mounted) return;

      setState(() {
        _messages.clear();

        // Sort by date (newest first)
        final sortedMessages = List<SmsMessage>.from(messages);
        sortedMessages.sort((a, b) {
          final dateA = int.tryParse(a.date?.toString() ?? '0') ?? 0;
          final dateB = int.tryParse(b.date?.toString() ?? '0') ?? 0;
          return dateB.compareTo(dateA);
        });

        _messages.addAll(sortedMessages);
        _isLoading = false;
      });
    });

    // Request permissions
    await smsService.requestPermission();

    // Always explicitly refresh messages after setup
    if (mounted) {
      await smsService.refreshMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Example'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final smsService = context.read<SmsService>();
                      await smsService.requestPermission();
                    },
                    child: const Text('Request Permission'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      final smsService = context.read<SmsService>();
                      await smsService.refreshMessages();
                    },
                    child: const Text('Refresh Messages'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No SMS messages found'))
                    : ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return ListTile(
                            title: Text(message.address ?? 'Unknown'),
                            subtitle: Text(message.body ?? 'No content'),
                            trailing: Text(_formatDate(message)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(SmsMessage message) {
    try {
      if (message.date != null) {
        final timestamp = int.tryParse(message.date.toString()) ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // Ignore date errors
    }
    return '';
  }
}
