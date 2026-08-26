// Firebase Project: zorvia-cc840
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'Firebase is not configured for Android in this project yet. '
          'Add google-services.json and configure Android options here.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase is not configured for iOS in this project yet. '
          'Add GoogleService-Info.plist and configure iOS options here.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Firebase Web configuration for project: zorvia-cc840
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD3ek9YbVyn8zAgwEfKAfDMICXh669DScQ',
    authDomain: 'zorvia-cc840.firebaseapp.com',
    projectId: 'zorvia-cc840',
    storageBucket: 'zorvia-cc840.firebasestorage.app',
    messagingSenderId: '281117677106',
    appId: '1:281117677106:web:2f428ea7ba0c2c6c280e2b',
    measurementId: 'G-HZFVGEJX1X',
  );
}
