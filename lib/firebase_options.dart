import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'services/app_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? _cachedOptions;

  static FirebaseOptions get currentPlatform {
    if (_cachedOptions != null) return _cachedOptions!;
    
    if (kIsWeb) {
      _cachedOptions = web;
      return _cachedOptions!;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _cachedOptions = android;
        return _cachedOptions!;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android in this project.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: AppConfig.firebaseAppId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    projectId: AppConfig.firebaseProjectId,
    storageBucket: AppConfig.firebaseStorageBucket,
    authDomain: '${AppConfig.firebaseProjectId}.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: AppConfig.firebaseAppId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    projectId: AppConfig.firebaseProjectId,
    storageBucket: AppConfig.firebaseStorageBucket,
  );
}
