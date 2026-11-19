class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String demoEmail = String.fromEnvironment('DEMO_EMAIL');
  static const String demoPassword = String.fromEnvironment('DEMO_PASSWORD');
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static Future<void> load() async {}

  static bool get enableDemoLogin {
    final raw = const String.fromEnvironment('ENABLE_DEMO_LOGIN').toLowerCase();
    if (raw.isEmpty) return true;
    return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on';
  }

  static bool get enableSmsAutoTrack {
    final raw = const String.fromEnvironment('ENABLE_SMS_AUTOTRACK').toLowerCase();
    if (raw.isEmpty) return false;
    return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on';
  }

  static bool get isBackendConfigured => apiBaseUrl.trim().isNotEmpty;

  static bool get isFirebaseConfigured {
    return firebaseApiKey.isNotEmpty &&
        firebaseAppId.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseProjectId.isNotEmpty &&
        firebaseStorageBucket.isNotEmpty;
  }
}
