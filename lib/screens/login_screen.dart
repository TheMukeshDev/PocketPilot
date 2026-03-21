import 'package:flutter/material.dart';

import '../services/app_logger.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goHome(String userId, String? displayName) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          userId: userId,
          displayName: displayName,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitEmailAuth() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _isRegisterMode
          ? await AuthService.instance.register(
              fullName: _fullNameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await AuthService.instance.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

      if (_isRegisterMode) {
        _showMessage(
          'Verification email sent. Please verify your email inbox before using all features.',
        );
      } else {
        final isVerified =
            await AuthService.instance.isCurrentUserEmailVerified();
        if (!isVerified) {
          _showMessage(
            'Your email is not verified yet. Open inbox to verify, or tap Resend Verification Email.',
          );
        }
      }

      _goHome(user.id, user.displayName);
    } catch (error, stackTrace) {
      await AppLogger.instance.error(
        'login_screen',
        _isRegisterMode ? 'Registration failed.' : 'Login failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'action': _isRegisterMode ? 'register' : 'login',
          'email': _emailController.text.trim().toLowerCase(),
        },
      );
      if (!mounted) return;
      _showMessage(
        AuthService.instance
            .userMessageFor(error, isRegistration: _isRegisterMode),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForgotPasswordDialog() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty) {
      return;
    }

    try {
      await AuthService.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent to $email');
    } catch (error) {
      _showMessage(
          AuthService.instance.userMessageFor(error, isRegistration: false));
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await AuthService.instance.sendVerificationEmailToCurrentUser();
      _showMessage('Verification email sent. Please check your inbox.');
    } catch (error) {
      _showMessage(
          AuthService.instance.userMessageFor(error, isRegistration: false));
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.instance.signInWithGoogle();
      _goHome(user.id, user.displayName);
    } catch (error, stackTrace) {
      await AppLogger.instance.error(
        'login_screen',
        'Google sign-in failed.',
        error: error,
        stackTrace: stackTrace,
        context: const {'action': 'google_sign_in'},
      );
      if (!mounted) return;
      _showMessage(
        AuthService.instance.userMessageFor(error, isRegistration: false),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _useDemoLogin() async {
    if (!AuthService.isDemoLoginEnabled) {
      _showMessage('Demo login is disabled for this build.');
      return;
    }

    setState(() {
      _isRegisterMode = false;
      _emailController.text = AuthService.demoEmail;
      _passwordController.text = AuthService.demoPassword;
    });
    await _submitEmailAuth();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Branding ──────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'PocketPilot',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track smart, spend smarter.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Google Sign-In (primary CTA) ─────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const _GoogleLogo(),
                    label: Text(
                      _isRegisterMode
                          ? 'Sign up with Google'
                          : 'Continue with Google',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colorScheme.outline,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── OR divider ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: colorScheme.outlineVariant,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or use email',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: colorScheme.outlineVariant,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Email form card ───────────────────────────────────
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isRegisterMode ? 'Create Account' : 'Sign in',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isRegisterMode) ...[
                            TextFormField(
                              controller: _fullNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (v) {
                                if (!_isRegisterMode) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || !v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _isLoading ? null : _submitEmailAuth,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isRegisterMode
                                        ? 'Create Account'
                                        : 'Sign In',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(
                                      () => _isRegisterMode = !_isRegisterMode,
                                    ),
                            child: Text(
                              _isRegisterMode
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create account',
                            ),
                          ),
                          if (!_isRegisterMode) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed:
                                  _isLoading ? null : _openForgotPasswordDialog,
                              child: const Text('Forgot password?'),
                            ),
                            TextButton(
                              onPressed:
                                  _isLoading ? null : _resendVerificationEmail,
                              child: const Text('Resend verification email'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Demo Login ────────────────────────────────────────
                if (AuthService.isDemoLoginEnabled) ...[
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _useDemoLogin,
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Try Demo Account'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AuthService.demoEmail}  ·  ${AuthService.demoPassword}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Simple Google "G" logo drawn with Text (no asset needed)
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF4285F4),
            height: 1,
          ),
        ),
      ),
    );
  }
}
