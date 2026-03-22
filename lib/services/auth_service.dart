import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/user.dart';
import 'app_config.dart';
import 'app_logger.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _sessionKey = 'auth_session';
  static const MethodChannel _platformChannel = MethodChannel(
    'pocketpilot/platform',
  );

  static bool get isDemoLoginEnabled {
    final demoEnabled = AppConfig.enableDemoLogin;
    final hasDemoEmail = (AppConfig.demoEmail ?? '').isNotEmpty;
    final hasDemoPassword = (AppConfig.demoPassword ?? '').isNotEmpty;
    
    if (demoEnabled && hasDemoEmail && hasDemoPassword) {
      return true;
    }
    
    return false;
  }

  static String get demoEmail => AppConfig.demoEmail ?? '';

  static String get demoPassword => AppConfig.demoPassword ?? '';

  GoogleSignIn? _activeGoogleSignIn;
  Future<void>? _firebaseInitialization;

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  Future<void> initialize() {
    return _firebaseInitialization ??= () async {
      if (!AppConfig.isFirebaseConfigured) {
        return;
      }
      
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    }();
  }

  bool get isFirebaseReady => AppConfig.isFirebaseConfigured;

  Future<void> restoreSession() async {
    try {
      await initialize();
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null && firebaseUser.email != null) {
        final user = await _appUserFromFirebaseUser(firebaseUser);
        await _persistSession(user);
        return;
      }
    } catch (_) {
      // Fall back to the locally persisted session if Firebase is unavailable.
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) {
      _currentUser = null;
      return;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    _currentUser = AppUser.fromMap(map);
  }

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      await initialize();

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const _AuthFailedException(
            'Registration failed. Please try again.');
      }

      final trimmedName = fullName.trim();
      if (trimmedName.isNotEmpty) {
        await firebaseUser.updateDisplayName(trimmedName);
      }

      try {
        await firebaseUser.sendEmailVerification();
      } catch (error, stackTrace) {
        await AppLogger.instance.warning(
          'auth',
          'Failed to send verification email after registration.',
          error: error,
          stackTrace: stackTrace,
          context: {
            'provider': 'password',
            'email': email.trim().toLowerCase(),
          },
        );
      }

      final user = await _appUserFromFirebaseUser(firebaseUser);
      await _persistSession(user);
      await AppLogger.instance.info(
        'auth',
        'Email registration succeeded.',
        context: {
          'provider': 'password',
          'email': email.trim().toLowerCase(),
        },
      );
      return user;
    } catch (error, stackTrace) {
      await AppLogger.instance.error(
        'auth',
        'Email registration failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'provider': 'password',
          'email': email.trim().toLowerCase(),
        },
      );
      rethrow;
    }
  }

  Future<bool> isCurrentUserEmailVerified() async {
    await initialize();
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return false;
    }
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await initialize();
    final normalized = email.trim();
    if (normalized.isEmpty) {
      throw const _AuthFailedException('Enter your email address first.');
    }
    await _firebaseAuth.sendPasswordResetEmail(email: normalized);
  }

  Future<void> sendVerificationEmailToCurrentUser() async {
    await initialize();
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const _AuthFailedException(
        'Log in with email/password first, then request verification email.',
      );
    }

    await user.reload();
    final refreshed = _firebaseAuth.currentUser;
    if (refreshed == null) {
      throw const _AuthFailedException(
        'Unable to read current user. Please login again.',
      );
    }

    if (refreshed.emailVerified) {
      throw const _AuthFailedException('Your email is already verified.');
    }

    await refreshed.sendEmailVerification();
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (_isDemoCredentials(email: email, password: password)) {
      final demoUser = AppUser(
        id: 'demo-user',
        email: demoEmail,
        displayName: 'Demo User',
        token: null,
      );
      await _persistSession(demoUser);
      return demoUser;
    }

    try {
      await initialize();

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const _AuthFailedException('Login failed. Please try again.');
      }

      final user = await _appUserFromFirebaseUser(firebaseUser);
      await _persistSession(user);
      await AppLogger.instance.info(
        'auth',
        'Email login succeeded.',
        context: {
          'provider': 'password',
          'email': email.trim().toLowerCase(),
        },
      );
      return user;
    } catch (error, stackTrace) {
      await AppLogger.instance.error(
        'auth',
        'Email login failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'provider': 'password',
          'email': email.trim().toLowerCase(),
        },
      );
      rethrow;
    }
  }

  Future<AppUser> signInWithGoogle() async {
    await initialize();

    try {
      final googleConfig = await _getGoogleSignInConfig();
      final configuredWebClientId =
          AppConfig.googleWebClientId ?? googleConfig.defaultWebClientId;

      if (!googleConfig.isConfigured && configuredWebClientId == null) {
        await AppLogger.instance.warning(
          'auth',
          'No Google web client id found in resources or dart-define. Trying Google sign-in without serverClientId.',
          context: const {'provider': 'google'},
        );
      }

      final googleSignIn =
          configuredWebClientId == null || configuredWebClientId.isEmpty
              ? GoogleSignIn()
              : GoogleSignIn(serverClientId: configuredWebClientId);
      _activeGoogleSignIn = googleSignIn;

      final account = await googleSignIn.signIn();
      if (account == null) {
        throw const _AuthCancelledException();
      }

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null || firebaseUser.email == null) {
        throw const _AuthFailedException('Google sign-in failed.');
      }

      final user = await _appUserFromFirebaseUser(firebaseUser);
      await _persistSession(user);
      await AppLogger.instance.info(
        'auth',
        'Google sign-in succeeded.',
        context: {
          'provider': 'google',
          'email': user.email,
          'hasDefaultWebClientId': googleConfig.defaultWebClientId != null,
          'hasManualWebClientId': AppConfig.googleWebClientId != null,
        },
      );
      return user;
    } on FirebaseAuthException catch (error, stackTrace) {
      await AppLogger.instance.error(
        'auth',
        'Google sign-in failed with FirebaseAuthException.',
        error: error,
        stackTrace: stackTrace,
        context: const {'provider': 'google'},
      );
      rethrow;
    } on PlatformException catch (error) {
      final mapped = _AuthFailedException(_platformErrorMessage(error));
      await AppLogger.instance.error(
        'auth',
        'Google sign-in failed with PlatformException.',
        error: error,
        stackTrace: error.stacktrace == null
            ? null
            : StackTrace.fromString(error.stacktrace!),
        context: const {'provider': 'google'},
      );
      throw mapped;
    } catch (error, stackTrace) {
      if (error is _AuthCancelledException || error is _AuthFailedException) {
        await AppLogger.instance.warning(
          'auth',
          'Google sign-in stopped before completion.',
          error: error,
          stackTrace: stackTrace,
          context: const {'provider': 'google'},
        );
        rethrow;
      }
      await AppLogger.instance.error(
        'auth',
        'Google sign-in failed with unexpected error.',
        error: error,
        stackTrace: stackTrace,
        context: const {'provider': 'google'},
      );
      throw _AuthFailedException(_googleSignInErrorMessage(error));
    }
  }

  Future<AppUser> signInWithDemo() async {
    final demoUser = AppUser(
      id: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
      email: 'demo@pocketpilot.app',
      displayName: 'Demo User',
      token: null,
    );
    await _persistSession(demoUser);
    await AppLogger.instance.info(
      'auth',
      'Demo login succeeded.',
      context: const {'provider': 'demo'},
    );
    return demoUser;
  }

  bool _isDemoCredentials({
    required String email,
    required String password,
  }) {
    if (!isDemoLoginEnabled) {
      return false;
    }

    return email.trim().toLowerCase() == demoEmail.trim().toLowerCase() &&
        password == demoPassword;
  }

  String userMessageFor(Object error, {required bool isRegistration}) {
    if (error is _AuthCancelledException) {
      return 'Sign-in cancelled.';
    }
    if (error is _AuthFailedException) {
      return error.message;
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'missing-email':
          return 'Enter your email address.';
        case 'email-already-in-use':
          return 'Email already registered.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'user-not-found':
          return isRegistration
              ? 'Registration failed. Please try again.'
              : 'No account found for this email.';
        case 'wrong-password':
          return 'Invalid email or password.';
        case 'requires-recent-login':
        case 'credential-too-old-login-again':
          return 'For security, please log in again and retry this action.';
        case 'network-request-failed':
          return 'Network error. Please check internet connection.';
        case 'account-exists-with-different-credential':
          return 'Account exists with a different sign-in method.';
        case 'invalid-credential':
          return 'Invalid credential. Please try again.';
        case 'operation-not-allowed':
          return isRegistration
              ? 'Email/password sign-up is disabled in Firebase.'
              : 'This sign-in method is disabled in Firebase.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return isRegistration
              ? 'Registration failed. Please try again.'
              : 'Login failed. Please try again.';
      }
    }
    return isRegistration
        ? 'Registration failed. Please try again.'
        : 'Login failed. Please try again.';
  }

  Future<void> logout() async {
    try {
      await initialize();
      await _firebaseAuth.signOut();
    } catch (_) {
      // Session cleanup should still continue locally.
    }

    try {
      await (_activeGoogleSignIn ?? GoogleSignIn()).signOut();
    } catch (_) {
      // Ignore Google sign-out failures during local logout.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    _currentUser = null;
  }

  Future<void> deleteCurrentAccount() async {
    await initialize();

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const _AuthFailedException('No authenticated account found.');
    }

    final accountEmail = firebaseUser.email;
    try {
      await firebaseUser.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login' ||
          error.code == 'credential-too-old-login-again') {
        throw const _AuthFailedException(
          'For security, please log in again and then delete your account.',
        );
      }
      rethrow;
    }

    try {
      await (_activeGoogleSignIn ?? GoogleSignIn()).signOut();
    } catch (_) {
      // Ignore Google sign-out failures during account deletion cleanup.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    _currentUser = null;

    await AppLogger.instance.info(
      'auth',
      'Account deleted successfully.',
      context: {
        'provider': 'account_delete',
        'email': accountEmail,
      },
    );
  }

  Future<void> _persistSession(AppUser user) async {
    final sessionUser = AppUser(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(sessionUser.toMap()));
    _currentUser = sessionUser;
  }

  Future<AppUser> _appUserFromFirebaseUser(User user) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const _AuthFailedException(
          'This account does not have an email address.');
    }

    return AppUser(
      id: user.uid,
      email: email,
      displayName: user.displayName,
    );
  }

  Future<_GoogleSignInConfig> _getGoogleSignInConfig() async {
    try {
      final response = await _platformChannel.invokeMapMethod<String, Object?>(
        'getGoogleSignInConfig',
      );
      final map = response ?? <String, Object?>{};
      final isConfigured = map['isConfigured'] == true;
      final defaultWebClientId = map['defaultWebClientId']?.toString();
      return _GoogleSignInConfig(
        isConfigured: isConfigured,
        defaultWebClientId:
            defaultWebClientId == null || defaultWebClientId.isEmpty
                ? null
                : defaultWebClientId,
      );
    } on MissingPluginException {
      return const _GoogleSignInConfig(isConfigured: true);
    } on PlatformException catch (error, stackTrace) {
      await AppLogger.instance.warning(
        'auth',
        'Unable to inspect Google sign-in configuration on platform channel.',
        error: error,
        stackTrace: stackTrace,
      );
      return const _GoogleSignInConfig(isConfigured: true);
    }
  }

  String _platformErrorMessage(PlatformException error) {
    switch (error.code) {
      case 'network_error':
        return 'Network error. Please check internet connection.';
      case 'sign_in_canceled':
      case 'sign_in_cancelled':
        return 'Sign-in cancelled.';
      case 'sign_in_failed':
        return _googleSignInErrorMessage(error);
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Google sign-in failed. Please try again.';
    }
  }

  String _googleSignInErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('10') || raw.contains('developer error')) {
      return 'Google sign-in is not configured for this Android app. Verify the package name, add the SHA-1 and SHA-256 fingerprints, enable Google sign-in, and if google-services.json still has empty oauth_client then create Android and Web OAuth clients manually in Google Cloud Console.';
    }
    if (raw.contains('network')) {
      return 'Network error. Please check internet connection.';
    }
    return 'Google sign-in failed. Please try again.';
  }
}

class _AuthCancelledException implements Exception {
  const _AuthCancelledException();
}

class _AuthFailedException implements Exception {
  const _AuthFailedException(this.message);

  final String message;
}

class _GoogleSignInConfig {
  const _GoogleSignInConfig({
    required this.isConfigured,
    this.defaultWebClientId,
  });

  final bool isConfigured;
  final String? defaultWebClientId;
}
