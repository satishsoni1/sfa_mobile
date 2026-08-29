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

  /// Firebase Web configuration for project: zorvia-cc840

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAtgGLEga4ludFAnoT6o1UCjHxPx469ZxM',
    appId: '1:706778349853:web:c631b3839dbd722164a1f4',
    messagingSenderId: '706778349853',
    projectId: 'fir-sfa-notification',
    authDomain: 'fir-sfa-notification.firebaseapp.com',
    storageBucket: 'fir-sfa-notification.firebasestorage.app',
    measurementId: 'G-C9HZ9WCRF9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAWtav_QGNjKU5uHVID_hfS608GtxeFn3c',
    appId: '1:706778349853:android:042f3cea499b054864a1f4',
    messagingSenderId: '706778349853',
    projectId: 'fir-sfa-notification',
    storageBucket: 'fir-sfa-notification.firebasestorage.app',
  );
}
