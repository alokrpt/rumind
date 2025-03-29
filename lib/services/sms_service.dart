import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();
  final _smsStreamController = StreamController<List<SmsMessage>>.broadcast();

  Stream<List<SmsMessage>> get smsStream => _smsStreamController.stream;
  bool _isInitialized = false;

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
      final messages = await _query.getAllSms;

      // Sort messages by date (latest first)
      messages.sort((a, b) {
        final dateA = int.tryParse(a.date?.toString() ?? '0') ?? 0;
        final dateB = int.tryParse(b.date?.toString() ?? '0') ?? 0;
        return dateB.compareTo(dateA); // Descending order (newest first)
      });

      _smsStreamController.add(messages);
      debugPrint('Loaded ${messages.length} SMS messages');
    } catch (e) {
      debugPrint('Error refreshing SMS messages: $e');
    }
  }

  Future<List<SmsMessage>> getMessages({
    String? address,
    List<SmsQueryKind> kinds = const [],
    int? count,
  }) async {
    try {
      final messages = await _query.querySms(
        address: address,
        kinds: kinds,
        count: count,
      );

      // Sort messages by date (latest first)
      messages.sort((a, b) {
        final dateA = int.tryParse(a.date?.toString() ?? '0') ?? 0;
        final dateB = int.tryParse(b.date?.toString() ?? '0') ?? 0;
        return dateB.compareTo(dateA); // Descending order (newest first)
      });

      return messages;
    } catch (e) {
      debugPrint('Error getting SMS messages: $e');
      return [];
    }
  }

  void dispose() {
    _smsStreamController.close();
  }
}
