import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/services/app_config.dart';
import 'package:budget_tracker/services/backend_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runs locally without backend or firebase config', () {
    expect(AppConfig.isBackendConfigured, isFalse);
    expect(AppConfig.isFirebaseConfigured, isFalse);
    expect(AppConfig.enableDemoLogin, isTrue);
    expect(BackendApiClient.instance.isConfigured, isFalse);
  });

  test('backend token loading works without network', () async {
    SharedPreferences.setMockInitialValues({});
    await BackendApiClient.instance.loadToken();
  });
}
