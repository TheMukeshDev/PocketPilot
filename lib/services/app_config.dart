import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String _googleWebClientIdFallback = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static const String _geminiApiKeyFallback = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String _mongoUriFallback = String.fromEnvironment(
    'MONGO_URI',
    defaultValue: '',
  );
  static const String _mongoDbNameFallback = String.fromEnvironment(
    'MONGO_DB_NAME',
    defaultValue: 'budget_tracker',
  );

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Missing local env file should not prevent app startup.
    }
  }

  static bool get enableDemoLogin => _boolValue(
        'ENABLE_DEMO_LOGIN',
        defaultValue: true,
      );

  static String? get demoEmail => _stringValue('DEMO_EMAIL');

  static String? get demoPassword => _stringValue('DEMO_PASSWORD');

  static bool get enableSmsAutoTrack => _boolValue(
        'ENABLE_SMS_AUTOTRACK',
        defaultValue: false,
      );

  static String? get googleWebClientId {
    final configured = _stringValue('GOOGLE_WEB_CLIENT_ID');
    if (configured != null) {
      return configured;
    }

    if (_googleWebClientIdFallback.trim().isEmpty) {
      return null;
    }

    return _googleWebClientIdFallback.trim();
  }

  static String? get geminiApiKey {
    final configured = _stringValue('GEMINI_API_KEY');
    if (configured != null) {
      return configured;
    }

    if (_geminiApiKeyFallback.trim().isEmpty) {
      return null;
    }

    return _geminiApiKeyFallback.trim();
  }

  static String? get mongoUri {
    final configured = _stringValue('MONGO_URI');
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    if (_mongoUriFallback.isNotEmpty) {
      return _mongoUriFallback;
    }

    return null;
  }

  static String get mongoDbName {
    final configured = _stringValue('MONGO_DB_NAME');
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    return _mongoDbNameFallback;
  }

  static String? _stringValue(String key) {
    try {
      final value = dotenv.maybeGet(key)?.trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  static bool _boolValue(
    String key, {
    required bool defaultValue,
  }) {
    final raw = _stringValue(key)?.toLowerCase();
    if (raw == null) {
      return defaultValue;
    }

    return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on';
  }

  static String? get firebaseApiKey {
    final value = _stringValue('FIREBASE_API_KEY');
    if (value != null) return value;
    
    final envValue = const String.fromEnvironment('FIREBASE_API_KEY');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseAppId {
    final value = _stringValue('FIREBASE_APP_ID');
    if (value != null) return value;
    
    final envValue = const String.fromEnvironment('FIREBASE_APP_ID');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseMessagingSenderId {
    final value = _stringValue('FIREBASE_MESSAGING_SENDER_ID');
    if (value != null) return value;
    
    final envValue = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseProjectId {
    final value = _stringValue('FIREBASE_PROJECT_ID');
    if (value != null) return value;
    
    final envValue = const String.fromEnvironment('FIREBASE_PROJECT_ID');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseStorageBucket {
    final value = _stringValue('FIREBASE_STORAGE_BUCKET');
    if (value != null) return value;
    
    final envValue = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    return envValue.isNotEmpty ? envValue : null;
  }

  static bool get isFirebaseConfigured =>
      firebaseApiKey != null &&
      firebaseAppId != null &&
      firebaseMessagingSenderId != null &&
      firebaseProjectId != null &&
      firebaseStorageBucket != null;
}
