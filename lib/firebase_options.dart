import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for $defaultTargetPlatform - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBBlCD0jxR8eFUU2gY7y6kSlV-MUrqzGuY',
    appId: '1:948498489629:web:f4522ab92ac51ea3a181f4',
    messagingSenderId: '948498489629',
    projectId: 'brain-train-hicypher',
    authDomain: 'brain-train-hicypher.firebaseapp.com',
    storageBucket: 'brain-train-hicypher.firebasestorage.app',
    measurementId: 'G-CV797G4MF9',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyApwjdsquEcuC6VhbDguC_xk-aM2ZLMWok',
    appId: '1:948498489629:ios:c6c456406bdba6e8a181f4',
    messagingSenderId: '948498489629',
    projectId: 'brain-train-hicypher',
    storageBucket: 'brain-train-hicypher.firebasestorage.app',
    iosBundleId: 'in.hicypher.braintrain.brainTrain',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDX6VFIUUNAzCrdOkBipHFVuIiWJo_WQjk',
    appId: '1:948498489629:android:322c77bd4b697e85a181f4',
    messagingSenderId: '948498489629',
    projectId: 'brain-train-hicypher',
    storageBucket: 'brain-train-hicypher.firebasestorage.app',
  );

}