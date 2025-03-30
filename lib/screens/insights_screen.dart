import 'dart:convert';
import 'dart:math' as math;

import 'package:brain_train/features/ai/gemini_chat_screen.dart';
import 'package:brain_train/services/gemini_service.dart';
import 'package:brain_train/services/monthly_limit_service.dart';
import 'package:brain_train/services/sms_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

class InsightsScreen extends StatefulWidget {
  final List<FinancialTransaction> transactions;

  const InsightsScreen({
    super.key,
    required this.transactions,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  late List<FinancialTransaction> _transactions;
  Map<TransactionType, int> _typeCountMap = {};
  Map<TransactionType, double> _typeAmountMap = {};
  double _totalAmount = 0;
  double _totalAmountThisMonth = 0;
  List<String> _merchants = [];

  // AI insights
  final GeminiService _geminiService = GeminiService();
  bool _isLoadingAi = false;
  Map<String, dynamic> _aiInsights = {'monthly': [], 'categories': [], 'recurring': []};
  String _aiError = '';
  bool _insightsCached = false;

  late TabController _tabController;

  // Add top merchants list
  List<MapEntry<String, double>> _topMerchants = [];

  // Monthly limit
  double? _monthlyLimit;
  bool _isLoadingLimit = true;

  @override
  void initState() {
    super.initState();
    _transactions = widget.transactions;
    _processTransactions();
    _tabController = TabController(length: 2, vsync: this);
    _loadMonthlyLimit();

    // Schedule AI insights generation for after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_insightsCached && _transactions.isNotEmpty) {
        _generateAiInsights();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No longer need tab listener since we're loading on init
  }

  void _processTransactions() {
    // Reset counters
    _typeCountMap = {};
    _typeAmountMap = {};
    _totalAmount = 0;
    _totalAmountThisMonth = 0;
    final merchantSet = <String>{};
    final Map<String, double> merchantAmounts = {};

    // Get current month and year for filtering
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    for (final transaction in _transactions) {
      // Count by type
      _typeCountMap[transaction.type] = (_typeCountMap[transaction.type] ?? 0) + 1;

      // Sum amounts by type
      if (transaction.amount != null) {
        try {
          final amount = double.parse(transaction.amount!);
          _typeAmountMap[transaction.type] = (_typeAmountMap[transaction.type] ?? 0) + amount;
          _totalAmount += amount;

          // Check if transaction is from current month
          if (transaction.date != null) {
            final transactionDate = DateTime.tryParse(transaction.date!);
            if (transactionDate != null && transactionDate.month == currentMonth && transactionDate.year == currentYear) {
              _totalAmountThisMonth += amount;
            }
          }

          // Track merchant amounts for top merchants
          if (transaction.merchant != null && transaction.merchant!.isNotEmpty) {
            final merchant = transaction.merchant!;
            merchantAmounts[merchant] = (merchantAmounts[merchant] ?? 0) + amount;
          }
        } catch (e) {
          // Skip invalid amounts
        }
      }

      // Collect merchants
      if (transaction.merchant != null && transaction.merchant!.isNotEmpty) {
        merchantSet.add(transaction.merchant!);
      }
    }

    // Get all merchants
    _merchants = merchantSet.toList()..sort();

    // Store top merchants by amount for display
    _topMerchants = merchantAmounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); // Sort by amount descending
  }

  Future<void> _generateAiInsights() async {
    if (_isLoadingAi) return;

    // Return cached insights if available
    if (_insightsCached && _aiInsights['monthly'].isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingAi = true;
      _aiError = '';
    });

    try {
      // Take only 50 most recent transactions for AI analysis
      final transactionSample = _getRepresentativeSample(_transactions);

      // Prepare optimized data for AI
      final transactionStrings = transactionSample.map((t) {
        final amount = t.amount ?? 'N/A';
        final date = t.date ?? 'N/A';
        final merchant = t.merchant ?? 'Unknown';
        final type = _formatTransactionType(t.type);
        return '$date: $amount to $merchant ($type)';
      }).toList();

      final insights = await _geminiService.generateFinancialInsights(transactionStrings);

      if (mounted) {
        setState(() {
          _aiInsights = insights;
          _isLoadingAi = false;
          _insightsCached = true;

          // Show spending insights popup after analysis completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndShowSpendingInsights();
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = 'Error: ${e.toString()}';
          _isLoadingAi = false;
        });
      }
    }
  }

  // Check monthly spending patterns and show insights popup if needed
  void _checkAndShowSpendingInsights() {
    // Only show popup if we have monthly data and aren't in error state
    if (_aiInsights['monthly'].isEmpty || _aiError.isNotEmpty) return;

    // Get current month data
    final monthlyData = _aiInsights['monthly'] as List;
    if (monthlyData.isEmpty) return;

    // Get current month and year
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Format current month name in the same format used in the data
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final expectedMonthFormat = "${monthNames[currentMonth - 1]}-$currentYear";

    // Find the data for the current month
    Map<String, dynamic>? currentMonthData;

    for (final monthData in monthlyData) {
      final monthStr = monthData['month'] as String;
      if (monthStr.contains(expectedMonthFormat)) {
        currentMonthData = monthData as Map<String, dynamic>;
        break;
      }
    }

    // If current month wasn't found, use the most recent month
    currentMonthData ??= monthlyData.last as Map<String, dynamic>;

    final currentMonthName = currentMonthData['month'] as String;
    final totalSpent = currentMonthData['total_spent'] as num;

    // Generate insights based on spending patterns
    final insights = <String>[];

    // Check monthly limit
    if (_monthlyLimit != null) {
      final percentUsed = (totalSpent / _monthlyLimit!).clamp(0.0, double.infinity);
      if (percentUsed >= 1.0) {
        insights.add('⚠️ You have exceeded your monthly limit of ₹${_monthlyLimit!.toStringAsFixed(2)}');
      } else if (percentUsed >= 0.8) {
        insights.add('⚠️ You are nearing your monthly limit (${(percentUsed * 100).toStringAsFixed(1)}% used)');
      }
    }

    // Find the previous month data
    Map<String, dynamic>? previousMonthData;
    final previousMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final previousYear = currentMonth == 1 ? currentYear - 1 : currentYear;
    final expectedPrevMonthFormat = "${monthNames[previousMonth - 1]}-$previousYear";

    for (final monthData in monthlyData) {
      final monthStr = monthData['month'] as String;
      if (monthStr.contains(expectedPrevMonthFormat)) {
        previousMonthData = monthData as Map<String, dynamic>;
        break;
      }
    }

    // Compare with previous month if available
    if (previousMonthData != null) {
      final previousMonthSpent = previousMonthData['total_spent'] as num;

      final difference = totalSpent - previousMonthSpent;
      final percentChange = previousMonthSpent > 0 ? (difference / previousMonthSpent) * 100 : 0;

      if (percentChange > 20) {
        insights.add('📈 Your spending is up ${percentChange.toStringAsFixed(1)}% compared to last month');
      } else if (percentChange < -20) {
        insights.add('📉 Your spending is down ${(-percentChange).toStringAsFixed(1)}% compared to last month');
      }
    }

    // Add top spending category if available
    if (_aiInsights['categories'].isNotEmpty) {
      final categories = _aiInsights['categories'] as List;
      if (categories.isNotEmpty) {
        final topCategory = categories.first;
        insights.add('💰 Your top spending category is ${topCategory['category']} (${topCategory['percentage']}%)');
      }
    }

    // Add a recurring payments insight if available
    if (_aiInsights['recurring'].isNotEmpty) {
      final recurring = _aiInsights['recurring'] as List;
      if (recurring.isNotEmpty) {
        final recurringTotal = recurring.fold<double>(0.0, (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble());

        final recurringPercentage = totalSpent > 0 ? (recurringTotal / totalSpent) * 100 : 0;
        insights.add('🔄 Recurring payments account for ${recurringPercentage.toStringAsFixed(1)}% of your spending');
      }
    }

    // Always add the total spending
    insights.add('💵 Total spent in $currentMonthName: ₹${totalSpent.toStringAsFixed(2)}');

    // Show popup if we have any insights
    if (insights.isNotEmpty) {
      _showSpendingInsightsDialog(currentMonthName, insights);
    }
  }

  void _showSpendingInsightsDialog(String month, List<String> insights) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$month Spending Insights'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(insight),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('GOT IT'),
          ),
          if (_monthlyLimit != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSetLimitDialog();
              },
              child: const Text('UPDATE LIMIT'),
            ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Get a representative sample of transactions for AI analysis
  List<FinancialTransaction> _getRepresentativeSample(List<FinancialTransaction> allTransactions) {
    return allTransactions;
    // if (allTransactions.length <= maxSize) {
    //   return allTransactions;
    // }

    // // Sort by date (most recent first) - assuming transactions have a date field
    // final sorted = List<FinancialTransaction>.from(allTransactions);
    // sorted.sort((a, b) {
    //   final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime(1970);
    //   final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime(1970);
    //   return dateB.compareTo(dateA); // Most recent first
    // });

    // // Take transactions from different time periods to get a better representation
    // final result = <FinancialTransaction>[];

    // // Most recent 20 transactions
    // result.addAll(sorted.take(20));

    // // Take 15 transactions from the middle
    // if (sorted.length > 40) {
    //   final middleStart = (sorted.length / 2).round() - 7;
    //   result.addAll(sorted.sublist(middleStart, middleStart + 15));
    // }

    // // Take 15 from the oldest transactions
    // if (sorted.length > 30) {
    //   result.addAll(sorted.sublist(sorted.length - 15));
    // }

    // // If we still have room, add more evenly distributed transactions
    // while (result.length < maxSize && result.length < sorted.length) {
    //   final index = (sorted.length * result.length / maxSize).round();
    //   if (index < sorted.length && !result.contains(sorted[index])) {
    //     result.add(sorted[index]);
    //   } else {
    //     break;
    //   }
    // }

    // return result.take(maxSize).toList();
  }

  Future<void> _loadMonthlyLimit() async {
    setState(() {
      _isLoadingLimit = true;
    });

    final limit = await MonthlyLimitService.getMonthlyLimit();

    if (mounted) {
      setState(() {
        _monthlyLimit = limit;
        _isLoadingLimit = false;
      });
    }
  }

  Future<void> _setMonthlyLimit(double amount) async {
    final success = await MonthlyLimitService.setMonthlyLimit(amount);
    if (success && mounted) {
      setState(() {
        _monthlyLimit = amount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Monthly limit set to ₹${amount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSetLimitDialog() {
    final TextEditingController limitController = TextEditingController(
      // Pre-fill with current limit if it exists
      text: _monthlyLimit != null ? _monthlyLimit!.toStringAsFixed(2) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_monthlyLimit == null ? 'Set Monthly Spending Limit' : 'Update Monthly Spending Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _monthlyLimit == null
                  ? 'Set a monthly spending limit to help track your expenses'
                  : 'Current limit: ₹${_monthlyLimit!.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: _monthlyLimit != null ? Colors.blue : null,
                fontWeight: _monthlyLimit != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: limitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monthly Limit (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final limitText = limitController.text.trim();
              if (limitText.isNotEmpty) {
                try {
                  final limit = double.parse(limitText);
                  if (limit > 0) {
                    Navigator.of(context).pop();
                    _setMonthlyLimit(limit);
                  }
                } catch (e) {
                  // Invalid input
                }
              }
            },
            child: Text(_monthlyLimit == null ? 'SET' : 'UPDATE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Financial Insights',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_isLoadingLimit)
            IconButton(
              icon: _monthlyLimit == null ? const Icon(Icons.add_card, color: Colors.white) : const Icon(Icons.edit_note, color: Colors.white),
              tooltip: _monthlyLimit == null ? 'Set Monthly Limit' : 'Update Monthly Limit',
              onPressed: _showSetLimitDialog,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'AI Analysis'),
          ],
        ),
      ),
      floatingActionButton: _shouldShowAiChatButton()
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GeminiChatScreen(
                      transactions: _aiInsights['monthly'].isNotEmpty || _aiInsights['categories'].isNotEmpty || _aiInsights['recurring'].isNotEmpty
                          ? null
                          : _transactions,
                      contextPrompt: _aiInsights['monthly'].isNotEmpty || _aiInsights['categories'].isNotEmpty || _aiInsights['recurring'].isNotEmpty
                          ? '''I'm looking at my financial insights with ${_transactions.length} transactions. Total spent: ₹${_totalAmount.toStringAsFixed(2)}.
                      
Here's the AI analysis of my finances:

MONTHLY SPENDING TRENDS:
${jsonEncode(_aiInsights['monthly'])}

SPENDING BY CATEGORY:
${jsonEncode(_aiInsights['categories'])}

RECURRING PAYMENTS:
${jsonEncode(_aiInsights['recurring'])}

Help me understand these insights better and answer any questions I have about my finances.'''
                          : "I'm looking at my financial insights screen with ${_transactions.length} transactions. "
                              "The total amount spent is ₹${_totalAmount.toStringAsFixed(2)}. "
                              "Help me understand my finances better or answer questions about my spending patterns.",
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Ask ${AppConstants.appName}'),
              tooltip: 'Chat with ${AppConstants.appName} about your finances',
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
      body: _transactions.isEmpty
          ? _buildEmptyState()
          : Container(
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInsights(),
                  _buildAiInsights(),
                ],
              ),
            ),
    );
  }

  bool _shouldShowAiChatButton() {
    // Show the button when AI insights are loaded and not empty
    // OR when insights are not being actively loaded but we have transactions to analyze
    return (!_isLoadingAi &&
            _insightsCached &&
            (_aiInsights['monthly'].isNotEmpty || _aiInsights['categories'].isNotEmpty || _aiInsights['recurring'].isNotEmpty)) ||
        (!_isLoadingAi && _transactions.isNotEmpty && _aiError.isEmpty);
  }

  Widget _buildBasicInsights() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Transaction Types'),
          const SizedBox(height: 12),
          _buildTransactionsByTypeSection(),
          const SizedBox(height: 24),
          _buildSectionTitle('Spending by Category'),
          const SizedBox(height: 12),
          _buildAmountByTypeSection(),
          const SizedBox(height: 24),
          _buildSectionTitle('Top Merchants'),
          const SizedBox(height: 12),
          _buildMerchantsSection(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildAiInsights() {
    // Don't automatically trigger AI analysis on build - wait for tab selection
    if (_isLoadingAi) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Analyzing transactions...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This may take a moment',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_aiError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
              const SizedBox(height: 24),
              Text(
                'Unable to generate AI insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _aiError,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateAiInsights,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiInsights['monthly'].isEmpty && !_isLoadingAi && !_insightsCached) {
      // Show loading placeholder with generate button
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 60, color: Theme.of(context).primaryColor.withOpacity(0.7)),
            const SizedBox(height: 24),
            Text(
              'AI insights not yet generated',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateAiInsights,
              icon: const Icon(Icons.auto_graph),
              label: const Text('Generate Insights'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analysis will be performed on your transaction data',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Clear cache and regenerate on pull-to-refresh
        setState(() {
          _insightsCached = false;
        });
        await _generateAiInsights();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly Limit Card
            InkWell(
              onTap: () {
                if (_monthlyLimit == null) {
                  _showSetLimitDialog();
                } else {
                  _checkAndShowSpendingInsights();
                }
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _monthlyLimit != null ? 'Monthly Limit Status' : 'Set a Monthly Limit',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _monthlyLimit != null
                                      ? (_getCurrentMonthSpending() >= _monthlyLimit!
                                          ? 'You have exceeded your monthly limit'
                                          : 'Track your spending against your limit')
                                      : 'Set a limit to track your monthly spending',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _monthlyLimit != null && _getCurrentMonthSpending() >= _monthlyLimit! ? Colors.red : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                      if (_monthlyLimit != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Limit: ₹${_monthlyLimit!.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Spent: ₹${_getCurrentMonthSpending().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getCurrentMonthSpending() >= _monthlyLimit! ? Colors.red : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_getCurrentMonthSpending() / _monthlyLimit!).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(_getCurrentMonthSpending() >= _monthlyLimit!
                                ? Colors.red
                                : (_getCurrentMonthSpending() / _monthlyLimit! > 0.8 ? Colors.orange : Colors.green)),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Monthly spending
            _buildAiSectionTitle('Monthly Spending Trends'),
            _buildMonthlySpendingSection(),
            const SizedBox(height: 24),

            // Categories
            _buildAiSectionTitle('Spending by Category'),
            _buildCategoriesSection(),
            const SizedBox(height: 24),

            // Recurring payments
            _buildAiSectionTitle('Recurring Payments'),
            _buildRecurringPaymentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildTransactionsByTypeSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions by Type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...TransactionType.values.map((type) {
              final count = _typeCountMap[type] ?? 0;
              if (count == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getTypeColor(type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_formatTransactionType(type)),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountByTypeSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount by Type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...TransactionType.values.map((type) {
              final amount = _typeAmountMap[type] ?? 0;
              if (amount == 0) return const SizedBox.shrink();

              // Calculate percentage of total
              final percentage = _totalAmount > 0 ? (amount / _totalAmount * 100) : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getTypeColor(type),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_formatTransactionType(type)),
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(_getTypeColor(type)),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantsSection() {
    if (_merchants.isEmpty) return const SizedBox.shrink();

    // Get top 10 merchants by spend
    final topMerchantsToShow = _topMerchants.take(10).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Merchants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '(${_merchants.length} total)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topMerchantsToShow.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final merchant = topMerchantsToShow[index];
                final percentage = _totalAmount > 0 ? (merchant.value / _totalAmount * 100) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatMerchantName(merchant.key),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹${merchant.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper to clean up and format merchant names
  String _formatMerchantName(String merchant) {
    // Handle common formatting issues in merchant names
    String formatted = merchant.trim();

    // Convert to title case if all uppercase
    if (formatted == formatted.toUpperCase() && formatted.length > 3) {
      formatted = formatted.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0] + word.substring(1).toLowerCase();
      }).join(' ');
    }

    // Remove extra spaces
    formatted = formatted.replaceAll(RegExp(r'\s+'), ' ');

    // Remove common transaction prefixes/suffixes
    final prefixes = ['tpf*', 'upi*', 'inf*', 'vpay*', 'utib', 'neft-'];
    for (final prefix in prefixes) {
      if (formatted.toLowerCase().startsWith(prefix)) {
        formatted = formatted.substring(prefix.length);
      }
    }

    return formatted.trim();
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
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No financial data to analyze',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'There are no financial transactions available for insights',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySpendingSection() {
    final List monthlyData = _aiInsights['monthly'] as List;
    final theme = Theme.of(context);

    if (monthlyData.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.query_stats,
                  size: 48,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No monthly data available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort monthly data chronologically
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final sortedMonthlyData = List.from(monthlyData);
    sortedMonthlyData.sort((a, b) {
      // Parse month strings (e.g., "Jan-2023")
      final aMonthStr = a['month'] as String;
      final bMonthStr = b['month'] as String;

      // Extract month and year
      final aMonthParts = aMonthStr.split('-');
      final bMonthParts = bMonthStr.split('-');

      if (aMonthParts.length < 2 || bMonthParts.length < 2) {
        return 0; // Invalid format, maintain original order
      }

      // Get month index
      final aMonthIndex = monthNames.indexOf(aMonthParts[0]);
      final bMonthIndex = monthNames.indexOf(bMonthParts[0]);

      // Get year
      final aYear = int.tryParse(aMonthParts[1]) ?? 0;
      final bYear = int.tryParse(bMonthParts[1]) ?? 0;

      // Compare years first, then months
      if (aYear != bYear) {
        return aYear.compareTo(bYear);
      }

      return aMonthIndex.compareTo(bMonthIndex);
    });

    // Find the current month index in the data
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final currentMonthName = "${monthNames[currentMonth - 1]}-$currentYear";

    // Determine which index should show a tooltip by default
    int initialTooltipIndex = -1;
    for (int i = 0; i < sortedMonthlyData.length; i++) {
      final month = sortedMonthlyData[i];
      final monthStr = month['month'] as String;
      if (monthStr == currentMonthName) {
        initialTooltipIndex = i;
        break;
      }
    }

    // Calculate max Y for the chart
    final maxY = sortedMonthlyData.fold(
          0.0,
          (max, month) => math.max(max, (month['total_spent'] as num).toDouble()),
        ) *
        1.2;

    // If there's a monthly limit and it's less than maxY, use it as a reference
    final extraLines = <HorizontalLine>[];
    if (_monthlyLimit != null && _monthlyLimit! < maxY) {
      extraLines.add(
        HorizontalLine(
          y: _monthlyLimit!,
          color: Colors.redAccent,
          strokeWidth: 2,
          dashArray: [5, 5], // Creates a dashed line
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(right: 5, bottom: 5),
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            labelResolver: (line) => 'Monthly Limit',
          ),
        ),
      );
    }

    // Find which month has highest spending
    int highestSpendingMonthIndex = 0;
    double highestSpending = 0;

    for (int i = 0; i < sortedMonthlyData.length; i++) {
      final month = sortedMonthlyData[i];
      final totalSpent = (month['total_spent'] as num).toDouble();
      if (totalSpent > highestSpending) {
        highestSpending = totalSpent;
        highestSpendingMonthIndex = i;
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Expenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Last ${sortedMonthlyData.length} Months',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Track your monthly spending patterns',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, left: 6, top: 12, bottom: 12),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      // This is a local state builder for the chart
                      // Initialize with showing tooltip for current month
                      int tooltipIndex = initialTooltipIndex;

                      // Prepare bar groups with tooltip indicators
                      final barGroups = <BarChartGroupData>[];
                      for (int i = 0; i < sortedMonthlyData.length; i++) {
                        final month = sortedMonthlyData[i];
                        final totalSpent = month['total_spent'] as num;

                        barGroups.add(
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: totalSpent.toDouble(),
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor.withOpacity(0.7),
                                    theme.colorScheme.secondary.withOpacity(0.9),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 20,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                              ),
                            ],
                            showingTooltipIndicators: i == tooltipIndex ? [0] : [],
                          ),
                        );
                      }

                      return BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          barTouchData: BarTouchData(
                            enabled: true,
                            handleBuiltInTouches: false, // We'll handle tooltip display ourselves
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                              tooltipRoundedRadius: 8,
                              tooltipPadding: const EdgeInsets.all(8),
                              tooltipMargin: 8,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final month = sortedMonthlyData[group.x.toInt()]['month'] as String;
                                final amount = rod.toY;
                                return BarTooltipItem(
                                  '$month\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: '₹${amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.yellow.shade100,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                              // Handle touch events to update which bar shows a tooltip
                              if (!event.isInterestedForInteractions || response == null || response.spot == null) {
                                return;
                              }

                              // Update the tooltip index when a bar is tapped
                              setState(() {
                                tooltipIndex = response.spot!.touchedBarGroupIndex;
                              });
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 55,
                                interval: maxY / 4,
                                getTitlesWidget: (value, meta) {
                                  // Format large numbers better
                                  String formattedValue;
                                  if (value >= 100000) {
                                    // Format as lakh for very large values (≥1 lakh)
                                    formattedValue = '₹${(value / 100000).toStringAsFixed(1)}L';
                                  } else if (value >= 1000) {
                                    // Format as k for thousands
                                    formattedValue = '₹${(value / 1000).toStringAsFixed(1)}k';
                                  } else {
                                    formattedValue = '₹${value.toInt()}';
                                  }

                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      formattedValue,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= sortedMonthlyData.length || value.toInt() < 0) {
                                    return const SizedBox.shrink();
                                  }
                                  final monthName = (sortedMonthlyData[value.toInt()]['month'] as String);
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      monthName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: value.toInt() == highestSpendingMonthIndex ? FontWeight.bold : FontWeight.normal,
                                        color: value.toInt() == highestSpendingMonthIndex ? theme.primaryColor : Colors.grey[600],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY / 5,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.withOpacity(0.2),
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              );
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: barGroups,
                          extraLinesData: ExtraLinesData(
                            horizontalLines: extraLines,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Stats cards
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_monthlyLimit != null)
                      _buildStatRow(
                        label: 'Monthly Limit',
                        value: '₹${_monthlyLimit!.toStringAsFixed(2)}',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                    if (sortedMonthlyData.isNotEmpty) ...[
                      _buildStatRow(
                        label: 'Average Monthly',
                        value: '₹${_calculateAverageMonthly(sortedMonthlyData).toStringAsFixed(2)}',
                        icon: Icons.calculate_rounded,
                        color: Colors.blue,
                      ),
                      _buildStatRow(
                        label: 'Highest Month',
                        value: '₹${highestSpending.toStringAsFixed(2)}',
                        icon: Icons.trending_up_rounded,
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),

              // Month details
              const SizedBox(height: 20),
              Text(
                'Monthly Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              ...sortedMonthlyData.asMap().entries.map((entry) {
                final index = entry.key;
                final month = entry.value;
                final monthName = month['month'] as String;
                final totalSpent = (month['total_spent'] as num).toDouble();
                final isHighestMonth = index == highestSpendingMonthIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isHighestMonth ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
                    border: Border.all(
                      color: isHighestMonth ? theme.primaryColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isHighestMonth)
                            Container(
                              padding: const EdgeInsets.all(4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_circle_up,
                                size: 12,
                                color: theme.primaryColor,
                              ),
                            ),
                          Text(
                            monthName,
                            style: TextStyle(
                              fontWeight: isHighestMonth ? FontWeight.bold : FontWeight.normal,
                              color: isHighestMonth ? theme.primaryColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${totalSpent.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isHighestMonth ? theme.primaryColor : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateAverageMonthly(List monthlyData) {
    if (monthlyData.isEmpty) return 0;

    double total = 0;
    for (final month in monthlyData) {
      total += (month['total_spent'] as num).toDouble();
    }

    return total / monthlyData.length;
  }

  Widget _buildStatRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categoryData = _aiInsights['categories'] as List;

    if (categoryData.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: const Text('No category data available'),
        ),
      );
    }

    // Softer pastel colors with reduced opacity
    final colors = [
      Colors.blue.withOpacity(0.7),
      Colors.red.withOpacity(0.7),
      Colors.green.withOpacity(0.7),
      Colors.orange.withOpacity(0.7),
      Colors.purple.withOpacity(0.7),
      Colors.teal.withOpacity(0.7),
      Colors.pink.withOpacity(0.7),
      Colors.amber.withOpacity(0.7),
      Colors.indigo.withOpacity(0.7),
      Colors.brown.withOpacity(0.7),
    ];

    // Map of category names to emojis
    final categoryEmojis = {
      'food': '🍽️',
      'grocery': '🛒',
      'groceries': '🛒',
      'dining': '🍽️',
      'restaurant': '🍽️',
      'restaurants': '🍽️',
      'eating out': '🍽️',
      'transport': '🚗',
      'transportation': '🚗',
      'travel': '✈️',
      'taxi': '🚕',
      'cab': '🚕',
      'entertainment': '🎬',
      'movies': '🎬',
      'streaming': '📺',
      'shopping': '🛍️',
      'online shopping': '🛍️',
      'retail': '👕',
      'clothing': '👕',
      'utilities': '💡',
      'bills': '📄',
      'utility': '💡',
      'housing': '🏠',
      'rent': '🏠',
      'mortgage': '🏠',
      'health': '💊',
      'healthcare': '🏥',
      'medical': '🏥',
      'medicine': '💊',
      'education': '📚',
      'school': '🎓',
      'college': '🎓',
      'books': '📚',
      'insurance': '🔒',
      'subscription': '📱',
      'subscriptions': '📱',
      'fitness': '🏋️',
      'gym': '🏋️',
      'transfer': '💸',
      'investment': '📈',
      'investments': '📈',
      'savings': '💰',
    };

    // Get category emoji or default
    String getCategoryEmoji(String category) {
      final lowercaseCategory = category.toLowerCase();

      // Check for exact matches
      if (categoryEmojis.containsKey(lowercaseCategory)) {
        return categoryEmojis[lowercaseCategory]!;
      }

      // Check for partial matches
      for (final entry in categoryEmojis.entries) {
        if (lowercaseCategory.contains(entry.key)) {
          return entry.value;
        }
      }

      // Default emoji if no match found
      return '📊';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: categoryData.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final color = colors[index % colors.length];
            final categoryName = category['category'] as String;
            final categoryEmoji = getCategoryEmoji(categoryName);

            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          categoryEmoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(category['percentage'] as num).toStringAsFixed(1)}% of total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${(category['amount'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (category['percentage'] as num).toDouble() / 100,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
                if (index < categoryData.length - 1) const Divider(height: 24),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRecurringPaymentsSection() {
    final recurringData = _aiInsights['recurring'] as List;

    if (recurringData.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: const Text('No recurring payments found'),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: recurringData.map((payment) {
          String payee = payment['payee'] as String;
          // Replace "manage your standing instructions" with "Standing transactions"
          if (payee.toLowerCase().contains('manage your standing instructions')) {
            payee = 'Standing transactions';
          }

          final amount = (payment['amount'] ?? 0) as num;
          final frequency = payment['frequency'] as String?;
          final nextPayment = payment['next_payment'] as String?;

          return ListTile(
            title: Text(
              payee,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('$frequency • Next: $nextPayment'),
            trailing: Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.calendar_today,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Add this method to get current month spending from AI insights
  double _getCurrentMonthSpending() {
    if (_aiInsights['monthly'].isEmpty) {
      return _totalAmountThisMonth; // Fall back to calculated value
    }

    // Get current month and year
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Format current month name in the same format used in the data
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final expectedMonthFormat = "${monthNames[currentMonth - 1]}-$currentYear";

    // Find current month data
    final monthlyData = _aiInsights['monthly'] as List;
    for (final monthData in monthlyData) {
      final monthStr = monthData['month'] as String;
      if (monthStr.contains(expectedMonthFormat)) {
        return (monthData['total_spent'] as num).toDouble();
      }
    }

    // If can't find exact match, use the most recent month
    if (monthlyData.isNotEmpty) {
      return (monthlyData.last['total_spent'] as num).toDouble();
    }

    return _totalAmountThisMonth;
  }
}
