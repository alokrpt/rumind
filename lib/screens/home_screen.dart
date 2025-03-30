import 'package:brain_train/constants/app_constants.dart';
import 'package:brain_train/features/ai/gemini_chat_screen.dart';
import 'package:brain_train/models/user_model.dart';
import 'package:brain_train/screens/gemini_test_screen.dart';
import 'package:brain_train/screens/sms_list_screen.dart';
import 'package:brain_train/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final UserModel? user;

  const HomeScreen({
    super.key,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildAppBar(context, authService),
                const SizedBox(height: 10),
                _buildWelcomeHeader(context),
                _buildQuickStats(context),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMenuGrid(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AuthService authService) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: IconButton(
              icon: const Icon(Icons.person_rounded, color: Colors.white),
              onPressed: () {
                if (user != null) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      user: user!,
                      authService: AuthService(),
                    ),
                  ));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: () => authService.signOut(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  '${user?.displayName ?? 'Friend'}! 👋',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ready to explore your finances?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.trending_up_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.attach_money_rounded,
              value: '₹X3,250',
              label: 'Monthly Spent',
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.receipt_long_rounded,
              value: '42',
              label: 'Transactions',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.pie_chart_rounded,
              value: '6',
              label: 'Categories',
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Explore Features',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.05,
          children: [
            _buildMenuCard(
              context,
              title: 'Financial Insights',
              subtitle: 'Track & analyze your spending',
              icon: Icons.currency_rupee_rounded,
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SmsListScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context,
              title: 'AI Assistant',
              subtitle: 'Ask questions about your finances',
              icon: Icons.chat_rounded,
              color: Colors.purple,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GeminiChatScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context,
              title: 'Financial Goals',
              subtitle: 'Set and track your goals',
              icon: Icons.flag_rounded,
              color: Colors.green,
              onTap: () {},
            ),
            _buildMenuCard(
              context,
              title: 'Settings',
              subtitle: 'Configure app preferences',
              icon: Icons.settings_rounded,
              color: Colors.orange,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GeminiTestScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
