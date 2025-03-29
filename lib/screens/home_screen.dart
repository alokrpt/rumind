import 'package:brain_train/constants/app_constants.dart';
import 'package:brain_train/models/user_model.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_2_outlined),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${user?.displayName ?? 'Player'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Start Training'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SmsListScreen(),
                  ),
                );
              },
              child: const Text('View SMS Messages'),
            ),
          ],
        ),
      ),
    );
  }
}
