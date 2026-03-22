import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'services/app_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? _cachedOptions;

  static FirebaseOptions get currentPlatform {
    if (_cachedOptions != null) return _cachedOptions!;
    
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web. Run flutterfire configure.',
      );
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

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey ?? 'MISSING_API_KEY',
        appId: AppConfig.firebaseAppId ?? 'MISSING_APP_ID',
        messagingSenderId: AppConfig.firebaseMessagingSenderId ?? 'MISSING_SENDER_ID',
        projectId: AppConfig.firebaseProjectId ?? 'MISSING_PROJECT_ID',
        storageBucket: AppConfig.firebaseStorageBucket ?? 'MISSING_BUCKET',
      );
}
