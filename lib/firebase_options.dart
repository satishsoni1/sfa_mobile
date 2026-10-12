// Firebase Project: secondary-sales-mobile-app
// Must stay in sync with android/app/google-services.json
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  /// Web options — no web client in current google-services.json.
  /// Kept for compile-time web targets; Android is the active mobile config.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyChAOFF1fPTQRD-2n4ZF3nbOjM74VG5BM4',
    appId: '1:875489413283:android:cc63d505a5f09a84f55716',
    messagingSenderId: '875489413283',
    projectId: 'secondary-sales-mobile-app',
    authDomain: 'secondary-sales-mobile-app.firebaseapp.com',
    storageBucket: 'secondary-sales-mobile-app.firebasestorage.app',
  );

  /// Android — matches android/app/google-services.json
  /// package: com.globalspace.himalaya
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChAOFF1fPTQRD-2n4ZF3nbOjM74VG5BM4',
    appId: '1:875489413283:android:cc63d505a5f09a84f55716',
    messagingSenderId: '875489413283',
    projectId: 'secondary-sales-mobile-app',
    storageBucket: 'secondary-sales-mobile-app.firebasestorage.app',
  );
}
