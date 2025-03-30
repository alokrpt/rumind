import 'package:brain_train/constants/app_constants.dart';
import 'package:brain_train/models/user_model.dart';
import 'package:brain_train/screens/home_screen.dart';
import 'package:brain_train/screens/login_screen.dart';
import 'package:brain_train/screens/sms_list_screen.dart';
import 'package:brain_train/services/auth_service.dart';
import 'package:brain_train/services/game_service.dart';
import 'package:brain_train/services/gemini_service.dart';
import 'package:brain_train/services/sms_service.dart';
import 'package:firebase_auth/firebase_auth.dart' if (skipFirebase) '';
import 'package:firebase_core/firebase_core.dart' if (skipFirebase) '';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

// Set to true to skip Firebase initialization when testing SMS functionality
const bool skipFirebase = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Firebase if not skipping
  if (!skipFirebase && Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Only add Firebase-related providers if not skipping
        if (!skipFirebase) ...[
          Provider<AuthService>(
            create: (_) => AuthService(),
          ),
          Provider<GameService>(
            create: (_) => GameService(),
          ),
          StreamProvider<User?>(
            create: (context) => FirebaseAuth.instance.authStateChanges(),
            initialData: null,
          ),
        ],
        // Always add SMS service
        Provider<SmsService>(
          create: (_) => SmsService(),
          dispose: (_, service) => service.dispose(),
        ),
        // Add GeminiService
        Provider<GeminiService>(
          create: (_) => GeminiService(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        // Skip Firebase-related code when testing SMS
        home: skipFirebase ? const SmsListScreen() : _buildFirebaseAuth(),
      ),
    );
  }

  Widget _buildFirebaseAuth() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularLoaderItem();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return FutureBuilder(
            future: context.read<GameService>().getUser(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const CircularLoaderItem();
              }

              if (userSnapshot.hasData) {
                return HomeScreen(
                  user: userSnapshot.data!,
                );
              }

              // If no user data exists, create a new user profile
              final newUser = UserModel(
                uid: user.uid,
                displayName: user.displayName ?? 'Player',
                email: user.email ?? '',
                photoURL: user.photoURL ?? '',
              );
              context.read<GameService>().createUser(newUser);

              return HomeScreen(user: newUser);
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class CircularLoaderItem extends StatelessWidget {
  const CircularLoaderItem({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
