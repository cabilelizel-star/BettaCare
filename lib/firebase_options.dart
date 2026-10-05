// firebase_options.dart
// Generated from your Firebase project config
// Project: BettaCare (bettacare-581cb)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  // ── Web ──
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA-Is2Cnr5zLax5Y8lUkexZZHwRmml7yDI',
    authDomain: 'bettacare-581cb.firebaseapp.com',
    projectId: 'bettacare-581cb',
    storageBucket: 'bettacare-581cb.appspot.com',
    messagingSenderId: '467295426201',
    appId: '1:467295426201:web:039f16b6213484a3044a08',
    measurementId: 'G-0RTWQYC107',
  );

  // ── Android ──
  // TODO: After adding Android app in Firebase Console,
  // download google-services.json and replace these values
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-Is2Cnr5zLax5Y8lUkexZZHwRmml7yDI',
    authDomain: 'bettacare-581cb.firebaseapp.com',
    projectId: 'bettacare-581cb',
    storageBucket: 'bettacare-581cb.appspot.com',
    messagingSenderId: '467295426201',
    appId: '1:467295426201:web:039f16b6213484a3044a08',
  );
}
