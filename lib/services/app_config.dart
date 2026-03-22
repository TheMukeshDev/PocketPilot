import 'package:flutter/services.dart';
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
      try {
        final manifestContent = await rootBundle.loadString('AssetManifest.json');
        if (manifestContent.contains('.env')) {
          final asset = await rootBundle.loadString('.env');
          dotenv.env.addAll(_parseEnvFile(asset));
        }
      } catch (_) {}
    }
  }

  static Map<String, String> _parseEnvFile(String content) {
    final result = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final idx = trimmed.indexOf('=');
      if (idx > 0) {
        final key = trimmed.substring(0, idx).trim();
        var value = trimmed.substring(idx + 1).trim();
        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }
        if (value.startsWith("'") && value.endsWith("'")) {
          value = value.substring(1, value.length - 1);
        }
        result[key] = value;
      }
    }
    return result;
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

    if (_googleWebClientIdFallback.trim().isNotEmpty) {
      return _googleWebClientIdFallback.trim();
    }

    return null;
  }

  static String? get geminiApiKey {
    final configured = _stringValue('GEMINI_API_KEY');
    if (configured != null) {
      return configured;
    }

    if (_geminiApiKeyFallback.trim().isNotEmpty) {
      return _geminiApiKeyFallback.trim();
    }

    return null;
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
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
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
    if (value != null && value.isNotEmpty) return value;
    
    const envValue = String.fromEnvironment('FIREBASE_API_KEY');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseAppId {
    final value = _stringValue('FIREBASE_APP_ID');
    if (value != null && value.isNotEmpty) return value;
    
    const envValue = String.fromEnvironment('FIREBASE_APP_ID');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseMessagingSenderId {
    final value = _stringValue('FIREBASE_MESSAGING_SENDER_ID');
    if (value != null && value.isNotEmpty) return value;
    
    const envValue = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseProjectId {
    final value = _stringValue('FIREBASE_PROJECT_ID');
    if (value != null && value.isNotEmpty) return value;
    
    const envValue = String.fromEnvironment('FIREBASE_PROJECT_ID');
    return envValue.isNotEmpty ? envValue : null;
  }

  static String? get firebaseStorageBucket {
    final value = _stringValue('FIREBASE_STORAGE_BUCKET');
    if (value != null && value.isNotEmpty) return value;
    
    const envValue = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    return envValue.isNotEmpty ? envValue : null;
  }

  static bool get isFirebaseConfigured {
    final apiKey = firebaseApiKey;
    final appId = firebaseAppId;
    final senderId = firebaseMessagingSenderId;
    final projectId = firebaseProjectId;
    final bucket = firebaseStorageBucket;
    
    final configured = apiKey != null &&
        appId != null &&
        senderId != null &&
        projectId != null &&
        bucket != null;
    
    return configured;
  }
}
