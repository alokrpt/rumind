import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyLimitService {
  static const String _limitKey = 'monthly_spending_limit';

  // Save the monthly limit to shared preferences
  static Future<bool> setMonthlyLimit(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setDouble(_limitKey, amount);
    } catch (e) {
      debugPrint('Error setting monthly limit: $e');
      return false;
    }
  }

  // Get the monthly limit from shared preferences
  static Future<double?> getMonthlyLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_limitKey);
    } catch (e) {
      debugPrint('Error getting monthly limit: $e');
      return null;
    }
  }

  // Check if a monthly limit exists
  static Future<bool> hasMonthlyLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_limitKey);
    } catch (e) {
      debugPrint('Error checking monthly limit: $e');
      return false;
    }
  }

  // Clear the monthly limit
  static Future<bool> clearMonthlyLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_limitKey);
    } catch (e) {
      debugPrint('Error clearing monthly limit: $e');
      return false;
    }
  }
}
