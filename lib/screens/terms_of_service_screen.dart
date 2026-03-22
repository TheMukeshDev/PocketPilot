import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: colorScheme.brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gavel_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms & Conditions',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last updated: March 2026',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context: context,
            title: '1. Acceptance of Terms',
            icon: Icons.check_circle_outline_rounded,
            content:
                'By downloading, installing, or using PocketPilot, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.\n\n'
                'We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '2. Description of Service',
            icon: Icons.apps_rounded,
            content:
                'PocketPilot is a personal finance and budget tracking application designed to help users, particularly students, manage their expenses and budgets effectively.\n\n'
                'The app provides features including:\n'
                '• Expense tracking and categorization\n'
                '• Budget management\n'
                '• SMS-based transaction detection\n'
                '• Receipt scanning\n'
                '• Gamification features (streaks, challenges)\n'
                '• Financial insights and reports',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '3. User Account & Registration',
            icon: Icons.person_outline_rounded,
            content:
                'To access certain features, you may need to create an account.\n\n'
                '• You must provide accurate and complete information\n'
                '• You are responsible for maintaining the security of your account\n'
                '• You must be at least 13 years old to create an account\n'
                '• One person or entity cannot maintain more than one account\n'
                '• We reserve the right to suspend or terminate accounts that violate these terms',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '4. Acceptable Use',
            icon: Icons.thumb_up_outlined,
            content:
                'You agree to:\n\n'
                '• Use the app only for lawful purposes\n'
                '• Not attempt to hack, modify, or reverse engineer the app\n'
                '• Not use the app to commit fraud or illegal activities\n'
                '• Not upload viruses or malicious code\n'
                '• Not spam or harass other users\n'
                '• Respect the intellectual property of PocketPilot\n\n'
                'Violation may result in account termination.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '5. Data Accuracy',
            icon: Icons.warning_amber_outlined,
            content:
                'PocketPilot is a tracking tool, not a financial institution.\n\n'
                '• You are responsible for verifying the accuracy of entered data\n'
                '• SMS detection may not capture all transactions\n'
                '• Budget alerts are estimates and may not reflect actual financial obligations\n'
                '• The app does not guarantee complete financial accuracy\n'
                '• Always verify with official bank statements for critical financial decisions',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '6. SMS & Permissions',
            icon: Icons.sms_outlined,
            content:
                'Using SMS detection features requires your permission.\n\n'
                '• SMS access is optional and can be disabled anytime\n'
                '• We only read transaction-related messages\n'
                '• SMS data is processed locally on your device\n'
                '• You can revoke SMS permissions through device settings',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '7. Payments & Transactions',
            icon: Icons.payment_outlined,
            content:
                'PocketPilot does not process payments.\n\n'
                '• All payment links and UPI integrations open external apps\n'
                '• We are not responsible for transactions made through third-party apps\n'
                '• Payment authentication happens within your bank\'s app\n'
                '• Check third-party app policies before making payments',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '8. Intellectual Property',
            icon: Icons.copyright_outlined,
            content:
                'All content, features, and functionality of PocketPilot are owned by us and are protected by copyright, trademark, and other intellectual property laws.\n\n'
                '• The PocketPilot name and logo are our trademarks\n'
                '• You retain ownership of content you create within the app\n'
                '• You grant us a license to use your content for app functionality',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '9. Disclaimer of Warranties',
            icon: Icons.info_outline_rounded,
            content:
                'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND.\n\n'
                '• We do not guarantee the app will be error-free or uninterrupted\n'
                '• We do not guarantee the accuracy of financial data\n'
                '• We are not responsible for data loss\n'
                '• You use the app at your own risk\n'
                '• No warranty is provided for third-party services integrated with the app',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '10. Limitation of Liability',
            icon: Icons.balance_outlined,
            content:
                'To the maximum extent permitted by law:\n\n'
                '• We shall not be liable for indirect, incidental, or consequential damages\n'
                '• Our total liability shall not exceed the amount you paid us (if any)\n'
                '• We are not liable for actions of third-party apps\n'
                '• We are not responsible for financial decisions made using the app',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '11. Indemnification',
            icon: Icons.shield_outlined,
            content:
                'You agree to indemnify and hold harmless PocketPilot, its developers, and affiliates from any claims, damages, or expenses arising from:\n\n'
                '• Your violation of these terms\n'
                '• Your misuse of the app\n'
                '• Any illegal activity conducted through your account',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '12. Termination',
            icon: Icons.cancel_outlined,
            content:
                'We may terminate or suspend your account:\n\n'
                '• For violating these terms\n'
                '• For prolonged inactivity\n'
                '• For any other reason at our discretion\n\n'
                'You may delete your account anytime through the app settings. Upon termination, certain provisions survive.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '13. Governing Law',
            icon: Icons.account_balance_outlined,
            content:
                'These terms are governed by applicable laws. Any disputes shall be resolved through:\n\n'
                '• Good faith negotiation between parties\n'
                '• Applicable consumer protection laws\n\n'
                'If you are located in India, these terms are governed by Indian laws.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '14. Contact Information',
            icon: Icons.mail_outline_rounded,
            content:
                'For questions about these Terms of Service:\n\n'
                '• Email: mukeshkumar916241@gmail.com\n\n'
                'We aim to respond to all inquiries within 48 hours.',
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colorScheme.primary.withOpacity(0.6),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'PocketPilot',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track smart, spend smarter.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.1',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
