import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA2LKFEQOmQhgFn48Ps5czeeKZpF-Rh8oI',
    appId: '1:111722606817:web:398e3896a672d82be9c7a0',
    messagingSenderId: '111722606817',
    projectId: 'optiflow-pk',
    authDomain: 'optiflow-pk.firebaseapp.com',
    storageBucket: 'optiflow-pk.firebasestorage.app',
    measurementId: 'G-YCTD88C47X',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2LKFEQOmQhgFn48Ps5czeeKZpF-Rh8oI',
    appId: '1:111722606817:web:398e3896a672d82be9c7a0',
    messagingSenderId: '111722606817',
    projectId: 'optiflow-pk',
    storageBucket: 'optiflow-pk.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA2LKFEQOmQhgFn48Ps5czeeKZpF-Rh8oI',
    appId: '1:111722606817:web:398e3896a672d82be9c7a0',
    messagingSenderId: '111722606817',
    projectId: 'optiflow-pk',
    authDomain: 'optiflow-pk.firebaseapp.com',
    storageBucket: 'optiflow-pk.firebasestorage.app',
  );
}
