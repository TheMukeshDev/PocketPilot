import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/budget_cycle_preferences.dart';
import '../services/date_cycle_service.dart';
import '../services/notification_preferences_service.dart';
import '../services/sms_tracking_preferences.dart';
import '../services/theme_service.dart';
import '../widgets/smart_date_selector.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.monthlyBudget,
    required this.rent,
    required this.budgetCycleStartDay,
    required this.smsApprovalMode,
    required this.onBudgetUpdated,
    required this.onRentUpdated,
    required this.onBudgetCycleStartDayUpdated,
    required this.onSmsApprovalModeUpdated,
  });

  final int monthlyBudget;
  final int rent;
  final int budgetCycleStartDay;
  final SmsApprovalMode smsApprovalMode;
  final void Function(int) onBudgetUpdated;
  final void Function(int) onRentUpdated;
  final void Function(int) onBudgetCycleStartDayUpdated;
  final void Function(SmsApprovalMode) onSmsApprovalModeUpdated;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late int _budget;
  late int _rent;
  late int _budgetCycleStartDay;
  late SmsApprovalMode _smsApprovalMode;
  ThemeMode _themeMode = ThemeService.instance.themeMode.value;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _masterNotificationsEnabled = true;
  bool _budgetAlertsEnabled = true;
  bool _streakUpdatesEnabled = true;
  bool _rewardsPointsEnabled = true;
  bool _reminderNotificationsEnabled = true;
  bool _isSavingBudget = false;
  bool _isSavingRent = false;

  @override
  void initState() {
    super.initState();
    _budget = widget.monthlyBudget;
    _rent = widget.rent;
    _budgetCycleStartDay = widget.budgetCycleStartDay;
    _smsApprovalMode = widget.smsApprovalMode;
    _loadNotificationPreferences();
    ThemeService.instance.themeMode.addListener(_onThemeChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    ThemeService.instance.themeMode.removeListener(_onThemeChanged);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await NotificationPreferencesService.instance.loadPreferences();
    if (mounted) {
      setState(() {
        _masterNotificationsEnabled = prefs.masterEnabled;
        _budgetAlertsEnabled = prefs.budgetAlertsEnabled;
        _streakUpdatesEnabled = prefs.streakUpdatesEnabled;
        _rewardsPointsEnabled = prefs.rewardsPointsEnabled;
        _reminderNotificationsEnabled = prefs.reminderNotificationsEnabled;
      });
    }
  }

  Future<void> _setMasterNotificationsEnabled(bool value) async {
    setState(() => _masterNotificationsEnabled = value);
    await NotificationPreferencesService.instance.setMasterEnabled(value);
  }

  Future<void> _setBudgetAlertsEnabled(bool value) async {
    setState(() => _budgetAlertsEnabled = value);
    await NotificationPreferencesService.instance
        .setCategoryEnabled(NotificationCategory.budgetAlerts, value);
  }

  Future<void> _setStreakUpdatesEnabled(bool value) async {
    setState(() => _streakUpdatesEnabled = value);
    await NotificationPreferencesService.instance
        .setCategoryEnabled(NotificationCategory.streakUpdates, value);
  }

  Future<void> _setRewardsPointsEnabled(bool value) async {
    setState(() => _rewardsPointsEnabled = value);
    await NotificationPreferencesService.instance
        .setCategoryEnabled(NotificationCategory.rewardsPoints, value);
  }

  Future<void> _setReminderNotificationsEnabled(bool value) async {
    setState(() => _reminderNotificationsEnabled = value);
    await NotificationPreferencesService.instance
        .setCategoryEnabled(NotificationCategory.reminderNotifications, value);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() => _themeMode = ThemeService.instance.themeMode.value);
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await ThemeService.instance.setThemeMode(mode);
  }

  Future<void> _saveSmsApprovalMode(SmsApprovalMode mode) async {
    final userId = AuthService.instance.currentUser?.id ?? 'guest';
    await SmsTrackingPreferences.saveForUser(userId, mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _smsApprovalMode = mode;
    });
    widget.onSmsApprovalModeUpdated(mode);
    _showSnackBar('Auto-Track mode updated to ${mode.label}', isSuccess: true);
  }

  Future<void> _openSmsApprovalModePicker() async {
    final selected = await showModalBottomSheet<SmsApprovalMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Auto-Track Mode',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Choose how PocketPilot handles SMS detection',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              for (final mode in SmsApprovalMode.values) ...[
                _SmsModeTile(
                  mode: mode,
                  isSelected: _smsApprovalMode == mode,
                  onTap: () => Navigator.of(ctx).pop(mode),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == _smsApprovalMode) {
      return;
    }

    await _saveSmsApprovalMode(selected);
  }

  String _budgetPreferenceKey(String userId) => 'monthly_budget_$userId';
  String _rentPreferenceKey(String userId) => 'monthly_rent_$userId';

  Future<void> _openBudgetCycleDialog() async {
    final dateService = DateCycleService.instance;
    final currentStartDay = _budgetCycleStartDay;
    final now = DateTime.now();
    final currentStartDate = DateTime(now.year, now.month, currentStartDay);

    DateTime selectedDate = currentStartDate;

    final updated = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Budget Cycle Start',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SmartDateSelector(
                  selectedDate: selectedDate,
                  onDateSelected: (date) {
                    setModalState(() {
                      selectedDate = date;
                    });
                  },
                  label: 'Select start date',
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(selectedDate),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (updated == null) return;

    final startDay = updated.day;
    final userId = AuthService.instance.currentUser?.id ?? 'guest';
    await BudgetCyclePreferences.saveForUser(userId, startDay);
    if (!mounted) return;
    setState(() {
      _budgetCycleStartDay = startDay;
    });
    widget.onBudgetCycleStartDayUpdated(startDay);

    final cycleStart = dateService.getCycleStart(updated);
    final cycleEnd = dateService.getCycleEnd(updated);
    final cycleInfo =
        'Cycle: ${dateService.formatDate(cycleStart)} → ${dateService.formatDate(cycleEnd)}';

    _showSnackBar('Budget cycle starts on day $startDay. $cycleInfo',
        isSuccess: true);
  }

  Future<void> _openBudgetDialog() async {
    final controller = TextEditingController(text: _budget.toString());
    final updated = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Monthly Budget',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  labelText: 'Budget amount',
                  prefixText: '₹ ',
                  prefixStyle: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final parsed = int.tryParse(controller.text.trim());
                      if (parsed == null || parsed <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(parsed);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (updated != null) {
      setState(() => _isSavingBudget = true);
      final prefs = await SharedPreferences.getInstance();
      final userId = AuthService.instance.currentUser?.id ?? 'guest';
      await prefs.setInt(_budgetPreferenceKey(userId), updated);
      if (!mounted) return;
      setState(() {
        _budget = updated;
        _isSavingBudget = false;
      });
      widget.onBudgetUpdated(updated);
      _showSnackBar('Monthly budget set to ₹$updated', isSuccess: true);
    }
  }

  Future<void> _openRentDialog() async {
    final controller = TextEditingController(text: _rent.toString());
    final updated = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.home_work_rounded,
                      color: Theme.of(ctx).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Monthly Rent',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  labelText: 'Rent amount',
                  prefixText: '₹ ',
                  prefixStyle: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(ctx).colorScheme.secondary,
                      ),
                  helperText: 'Set 0 if not applicable',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.secondary,
                    ),
                    onPressed: () {
                      final parsed = int.tryParse(controller.text.trim());
                      if (parsed == null || parsed < 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(parsed);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (updated != null) {
      setState(() => _isSavingRent = true);
      final prefs = await SharedPreferences.getInstance();
      final userId = AuthService.instance.currentUser?.id ?? 'guest';
      await prefs.setInt(_rentPreferenceKey(userId), updated);
      if (!mounted) return;
      setState(() {
        _rent = updated;
        _isSavingRent = false;
      });
      widget.onRentUpdated(updated);
      _showSnackBar('Monthly rent updated to ₹$updated', isSuccess: true);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Log out'),
          ],
        ),
        content: const Text(
          'You will be signed out of PocketPilot. Your data will be safely stored on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone.',
            ),
            SizedBox(height: 12),
            Text(
              'Your account sign-in will be removed and you will lose all synced cloud data.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await AuthService.instance.deleteCurrentAccount();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      _showSnackBar('Account deleted successfully', isSuccess: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        AuthService.instance.userMessageFor(error, isRegistration: false),
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isSuccess)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
            else if (isError)
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20)
            else
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: MediaQuery.of(context).size.width > 500 ? 400 : null,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse('https://pocketpilot.app/privacy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTermsOfService() async {
    final url = Uri.parse('https://pocketpilot.app/terms');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSupport() async {
    final url = Uri.parse('mailto:support@pocketpilot.app');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _rateApp() async {
    final url = Uri.parse('https://play.google.com/store/apps/details?id=app.pocketpilot');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Clear Local Data'),
          ],
        ),
        content: const Text(
          'This will delete all locally stored expenses and preferences. Your cloud-synced data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              _showSnackBar('Local data cleared. Please restart the app.', isError: true);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUser = AuthService.instance.currentUser;
    final displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!
        : currentUser?.email.split('@').first ?? 'Guest';
    final email = currentUser?.email ?? '';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.primaryContainer.withOpacity(0.5),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 14,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PocketPilot User',
                                          style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Appearance'),
                    _buildSettingsCard([
                      _buildThemeSelector(),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Account'),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: colorScheme.primary,
                        title: 'Monthly Budget',
                        subtitle: '₹$_budget',
                        trailing: _isSavingBudget
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap: _openBudgetDialog,
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.home_work_rounded,
                        iconColor: colorScheme.secondary,
                        title: 'Monthly Rent',
                        subtitle: _rent == 0 ? 'Not set (₹0)' : '₹$_rent',
                        trailing: _isSavingRent
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap: _openRentDialog,
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: colorScheme.tertiary,
                        title: 'Budget Cycle Start',
                        subtitle: 'Day $_budgetCycleStartDay of every month',
                        onTap: _openBudgetCycleDialog,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('SMS Tracking'),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Icons.sms_rounded,
                        iconColor: colorScheme.primary,
                        title: 'Auto-Track Mode',
                        subtitle: _smsApprovalMode.description,
                        badge: _smsApprovalMode.label,
                        badgeColor: colorScheme.primaryContainer,
                        badgeTextColor: colorScheme.primary,
                        onTap: _openSmsApprovalModePicker,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Notifications'),
                    _buildSettingsCard([
                      _buildSwitchTile(
                        icon: Icons.notifications_rounded,
                        iconColor: colorScheme.primary,
                        title: 'Push Notifications',
                        subtitle: _masterNotificationsEnabled
                            ? 'Receive notifications from PocketPilot'
                            : 'Notifications are disabled',
                        value: _masterNotificationsEnabled,
                        onChanged: _setMasterNotificationsEnabled,
                      ),
                      if (_masterNotificationsEnabled) ...[
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.amber.shade700,
                          title: 'Budget Alerts',
                          subtitle: 'Overspending warnings',
                          value: _budgetAlertsEnabled,
                          onChanged: _setBudgetAlertsEnabled,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orange,
                          title: 'Streak Updates',
                          subtitle: 'Milestones and streak breaks',
                          value: _streakUpdatesEnabled,
                          onChanged: _setStreakUpdatesEnabled,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.emoji_events_rounded,
                          iconColor: Colors.purple,
                          title: 'Rewards & Points',
                          subtitle: 'Challenge completions and badges',
                          value: _rewardsPointsEnabled,
                          onChanged: _setRewardsPointsEnabled,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.notifications_active_rounded,
                          iconColor: colorScheme.secondary,
                          title: 'Reminders',
                          subtitle: 'Daily tips and engagement',
                          value: _reminderNotificationsEnabled,
                          onChanged: _setReminderNotificationsEnabled,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Support'),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Icons.star_rounded,
                        iconColor: Colors.amber,
                        title: 'Rate PocketPilot',
                        subtitle: 'Love the app? Rate us on Play Store',
                        onTap: _rateApp,
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.help_outline_rounded,
                        iconColor: colorScheme.primary,
                        title: 'Help & Support',
                        subtitle: 'Get help or send feedback',
                        onTap: _openSupport,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Legal'),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: colorScheme.primary,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        showArrow: true,
                        onTap: _openPrivacyPolicy,
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.description_outlined,
                        iconColor: colorScheme.primary,
                        title: 'Terms of Service',
                        subtitle: 'Usage terms and conditions',
                        showArrow: true,
                        onTap: _openTermsOfService,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Danger Zone'),
                    _buildSettingsCard([
                      _buildSettingsTile(
                        icon: Icons.delete_sweep_rounded,
                        iconColor: colorScheme.error,
                        title: 'Clear Local Data',
                        subtitle: 'Delete local expenses and preferences',
                        onTap: _showClearDataDialog,
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.logout_rounded,
                        iconColor: colorScheme.error,
                        title: 'Log out',
                        subtitle: 'Sign out of PocketPilot',
                        onTap: _logout,
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        icon: Icons.delete_forever_rounded,
                        iconColor: colorScheme.error,
                        title: 'Delete Account',
                        subtitle: 'Permanently remove your account',
                        isDestructive: true,
                        onTap: _deleteAccount,
                      ),
                    ]),
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'PocketPilot v1.0.1',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Made with ♥ in India',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
    bool showArrow = false,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? colorScheme.error : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor ?? colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: textTheme.labelSmall?.copyWith(
                      color: badgeTextColor ?? colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (showArrow)
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 74,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withOpacity(0.5),
    );
  }

  Widget _buildThemeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getThemeLabel(),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded, size: 18),
                label: Text('Auto'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {_themeMode},
            onSelectionChanged: (selected) => _setTheme(selected.first),
            style: SegmentedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Always light theme';
      case ThemeMode.dark:
        return 'Always dark theme';
      case ThemeMode.system:
        return 'Follows system setting';
    }
  }
}

class _SmsModeTile extends StatelessWidget {
  const _SmsModeTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final SmsApprovalMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getModeIcon(),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                )
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (mode) {
      case SmsApprovalMode.askEveryTime:
        return Icons.help_rounded;
      case SmsApprovalMode.alwaysApprove:
        return Icons.check_circle_outline_rounded;
      case SmsApprovalMode.alwaysAddDirectly:
        return Icons.flash_on_rounded;
    }
  }
}
