import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
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
                  Icons.shield_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Privacy Matters',
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
            title: '1. Introduction',
            icon: Icons.info_outline_rounded,
            content:
                'PocketPilot ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our budget tracking app designed for students.\n\nBy using PocketPilot, you agree to the collection and use of information in accordance with this policy.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '2. Information We Collect',
            icon: Icons.folder_outlined,
            content:
                'We collect the following types of information:\n\n'
                '• Profile Information: Name, email address, and profile picture (if you sign in via Google Sign-In)\n\n'
                '• Expense Data: Records of your expenses including amount, category, date, and notes\n\n'
                '• Budget Data: Your monthly budget limits and spending targets\n\n'
                '• Gamification Data: Streaks, challenges, points, and achievements\n\n'
                '• Notification Preferences: Your choices for receiving app notifications\n\n'
                '• Device Information: Basic device details for app functionality',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '3. How We Use Your Information',
            icon: Icons.widgets_outlined,
            content:
                'We use your information to:\n\n'
                '• Provide and maintain the app\'s core functionality\n\n'
                '• Track your expenses and budget against limits\n\n'
                '• Send you relevant notifications (budget alerts, reminders)\n\n'
                '• Manage gamification features (streaks, challenges, rewards)\n\n'
                '• Sync your data across devices when signed in\n\n'
                '• Improve the app based on usage patterns\n\n'
                '• Respond to your support requests',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '4. SMS & Notification Permissions',
            icon: Icons.sms_outlined,
            content:
                'SMS Tracking (Optional):\n'
                'If enabled, PocketPilot uses SMS permissions to automatically detect transaction-related messages from banks and payment apps. This feature helps you track expenses without manual entry.\n\n'
                '• We only read SMS messages related to financial transactions\n'
                '• SMS data is processed on-device and is not stored on our servers\n'
                '• You can disable SMS tracking anytime in Settings\n\n'
                'Push Notifications:\n'
                'We may send push notifications for budget alerts, streak updates, and app reminders. You can customize notification preferences or disable them entirely.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '5. Receipt Scanning & OCR',
            icon: Icons.document_scanner_outlined,
            content:
                'PocketPilot offers a receipt scanning feature that uses optical character recognition (OCR) to extract expense details from photos.\n\n'
                '• Receipt images are processed to extract text data only\n'
                '• Original images are not stored on our servers\n'
                '• OCR processing happens on-device or through secure cloud services\n'
                '• You can delete scanned receipt data anytime',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '6. Payment Handling',
            icon: Icons.payment_rounded,
            content:
                'PocketPilot is a budget tracking app and does not process payments directly.\n\n'
                '• UPI and payment links open external, trusted payment apps\n'
                '• We do not store bank account numbers, card details, or PINs\n'
                '• Payment authentication happens entirely within your bank\'s app\n'
                '• All financial transactions are between you and your payment provider',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '7. Data Security',
            icon: Icons.security_rounded,
            content:
                'We take data security seriously:\n\n'
                '• Your data is stored securely using Firebase (Firestore) and local SQLite\n'
                '• Firebase Authentication handles user login securely\n'
                '• Data transmitted between your device and our services is encrypted\n'
                '• We regularly review and update our security practices\n\n'
                'While we strive to protect your information, no method of transmission over the internet is 100% secure.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '8. User Choices and Controls',
            icon: Icons.tune_rounded,
            content:
                'You have control over your data:\n\n'
                '• Edit or delete your profile information anytime\n'
                '• Disable SMS tracking in Settings\n'
                '• Customize or disable push notifications\n'
                '• Delete individual expenses or clear all local data\n'
                '• Export your data before deleting your account\n'
                '• Delete your account and associated data permanently\n\n'
                'To exercise any of these options, use the Settings screen in the app or contact us.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '9. Children\'s Privacy',
            icon: Icons.child_care_rounded,
            content:
                'PocketPilot is designed for students and general audiences. While our app may be used by minors, we do not knowingly collect personal information from children under 13 without parental consent as per applicable laws.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '10. Changes to This Policy',
            icon: Icons.update_rounded,
            content:
                'We may update this Privacy Policy from time to time. We will notify you of significant changes by:\n\n'
                '• Posting the updated policy in the app\n'
                '• Updating the "Last updated" date above\n'
                '• Sending a notification for major changes\n\n'
                'We encourage you to review this policy periodically.',
          ),
          const SizedBox(height: 20),
          _buildSection(
            context: context,
            title: '11. Contact Us',
            icon: Icons.mail_outline_rounded,
            content:
                'If you have questions, concerns, or requests regarding this Privacy Policy or your data:\n\n'
                '• Email: mukeshkumar916241@gmail.com\n\n'
                'We aim to respond to all privacy-related inquiries within 48 hours.',
            showContactButton: true,
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
    bool showContactButton = false,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.85),
                  height: 1.5,
                ),
              ),
              if (showContactButton) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _launchEmail(context),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Contact Us'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final mailtoUri = Uri.parse(
      'mailto:mukeshkumar916241@gmail.com?subject=Privacy%20Policy%20Inquiry',
    );

    try {
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No email app found on this device.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open email app.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
