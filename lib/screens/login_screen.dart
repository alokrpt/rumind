import 'package:brain_train/constants/app_constants.dart';
import 'package:brain_train/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAppLogo(context),
                    const SizedBox(height: 40),
                    _buildWelcomeText(context),
                    const SizedBox(height: 180),
                    _buildLoginButton(
                      context,
                      icon: Icons.email_outlined,
                      text: 'Sign in with Email',
                      color: Colors.blue,
                      onPressed: () async {
                        try {
                          await authService.signInWithEmailAndPassword('test@example.com', 'password123');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                    // const SizedBox(height: 16),
                    // _buildLoginButton(
                    //   context,
                    //   icon: Icons.facebook,
                    //   text: 'Sign in with Facebook',
                    //   color: Color(0xFF1877F2),
                    //   onPressed: () async {
                    //     try {
                    //       await authService.signInWithFacebook();
                    //     } catch (e) {
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         SnackBar(content: Text('Error: ${e.toString()}')),
                    //       );
                    //     }
                    //   },
                    // ),
                    // const SizedBox(height: 16),
                    // _buildLoginButton(
                    //   context,
                    //   icon: Icons.apple,
                    //   text: 'Sign in with Apple',
                    //   color: Colors.black,
                    //   onPressed: () async {
                    //     try {
                    //       await authService.signInWithApple();
                    //     } catch (e) {
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         SnackBar(content: Text('Error: ${e.toString()}')),
                    //       );
                    //     }
                    //   },
                    // ),
                    const SizedBox(height: 16),
                    _buildLoginButton(
                      context,
                      icon: Icons.g_mobiledata_rounded,
                      text: 'Sign in with Google',
                      color: Colors.red,
                      onPressed: () async {
                        try {
                          await authService.signInWithGoogle();
                        } catch (e) {
                          debugPrint(e.toString());
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.psychology,
        color: Colors.white,
        size: 80,
      ),
    );
  }

  Widget _buildWelcomeText(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
          child: Text(
            'Welcome Back',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
