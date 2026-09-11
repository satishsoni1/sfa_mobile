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
        return android;
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

  /// Firebase Web configuration for project: aurobindo

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDIofuhNzvLSQ89W3v4Eg_hvpbXwWWapnY',
    appId: '1:615438101526:web:b912d5db6686b19dfa5937',
    messagingSenderId: '615438101526',
    projectId: 'himalaya-e7d22',
    authDomain: 'himalaya-e7d22.firebaseapp.com',
    storageBucket: 'himalaya-e7d22.firebasestorage.app',
    measurementId: 'G-M74BFVDN5X',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAnzOtwTTVjYgHRax4xWn_APMN5gRN8MBY',
    appId: '1:615438101526:android:5bea291e2c6dca6ffa5937',
    messagingSenderId: '615438101526',
    projectId: 'himalaya-e7d22',
    storageBucket: 'himalaya-e7d22.firebasestorage.app',
  );
}
