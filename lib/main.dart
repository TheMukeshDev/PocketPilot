import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_config.dart';
import 'services/app_logger.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await AppLogger.instance.initialize();
  _configureGlobalErrorLogging();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    await AppLogger.instance.error(
      'startup',
      'Firebase initialization failed before app start.',
      error: error,
      stackTrace: stackTrace,
    );
  }
  await _warmUpServices();
  runApp(const MyApp());
}

void _configureGlobalErrorLogging() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(AppLogger.instance.recordFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      AppLogger.instance.error(
        'platform',
        'Unhandled platform error.',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return false;
  };
}

Future<void> _warmUpServices() async {
  try {
    await AuthService.instance.initialize();
  } catch (error, stackTrace) {
    await AppLogger.instance.error(
      'startup',
      'Firebase initialization failed during warm-up.',
      error: error,
      stackTrace: stackTrace,
    );
    // AuthService surfaces a user-facing message if Firebase is misconfigured.
  }

  try {
    await DatabaseService.instance.initDatabase();
  } catch (error, stackTrace) {
    await AppLogger.instance.error(
      'startup',
      'Database initialization failed during warm-up.',
      error: error,
      stackTrace: stackTrace,
    );
    // Database will retry on first access.
  }

  try {
    await ThemeService.instance.loadThemeMode();
  } catch (error, stackTrace) {
    await AppLogger.instance.warning(
      'startup',
      'Theme restoration failed during warm-up.',
      error: error,
      stackTrace: stackTrace,
    );
    // Theme defaults to system if it cannot be restored.
  }

  try {
    await NotificationService.instance.initialize();
  } catch (error, stackTrace) {
    await AppLogger.instance.warning(
      'startup',
      'Notification initialization failed during warm-up.',
      error: error,
      stackTrace: stackTrace,
    );
    // Notifications are optional.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'PocketPilot',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: _buildAppTheme(Brightness.light),
          darkTheme: _buildAppTheme(Brightness.dark),
          initialRoute: '/',
          routes: {
            '/': (context) => home ?? const _AuthGate(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
          },
        );
      },
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: brightness,
  );

  final colorScheme = baseScheme.copyWith(
    primary: const Color(0xFF0F766E),
    onPrimary: Colors.white,
    secondary: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
    tertiary: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
    error: const Color(0xFFDC2626),
    surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    surfaceVariant: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
    primaryContainer:
        isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
    secondaryContainer:
        isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
    tertiaryContainer:
        isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
    errorContainer: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
    cardColor: colorScheme.surface,
    dividerColor: colorScheme.outlineVariant,
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<_AuthGateResult> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _checkAuthAndOnboarding();
  }

  Future<_AuthGateResult> _checkAuthAndOnboarding() async {
    await AuthService.instance.restoreSession();
    
    if (AuthService.instance.currentUser == null) {
      return const _AuthGateResult(showLogin: true);
    }
    
    final shouldShowOnboarding = await OnboardingScreen.shouldShow();
    if (shouldShowOnboarding) {
      return const _AuthGateResult(showOnboarding: true);
    }
    
    return const _AuthGateResult(showHome: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthGateResult>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return const LoginScreen();
        }

        if (result.showLogin) {
          return const LoginScreen();
        }

        if (result.showOnboarding) {
          return const OnboardingScreen();
        }

        return const HomeScreen();
      },
    );
  }
}

class _AuthGateResult {
  const _AuthGateResult({
    this.showLogin = false,
    this.showOnboarding = false,
    this.showHome = false,
  });

  final bool showLogin;
  final bool showOnboarding;
  final bool showHome;
}
