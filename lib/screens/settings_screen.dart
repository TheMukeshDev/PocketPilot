import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/budget_cycle_preferences.dart';
import '../services/date_cycle_service.dart';
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

class _SettingsScreenState extends State<SettingsScreen> {
  late int _budget;
  late int _rent;
  late int _budgetCycleStartDay;
  late SmsApprovalMode _smsApprovalMode;
  ThemeMode _themeMode = ThemeService.instance.themeMode.value;

  // Language list — extend when i18n is added.
  static const List<_LangOption> _languages = [
    _LangOption('English', 'en', '🇬🇧'),
    _LangOption('हिन्दी', 'hi', '🇮🇳'),
    _LangOption('தமிழ்', 'ta', '🇮🇳'),
    _LangOption('తెలుగు', 'te', '🇮🇳'),
  ];
  String _selectedLang = 'en';

  @override
  void initState() {
    super.initState();
    _budget = widget.monthlyBudget;
    _rent = widget.rent;
    _budgetCycleStartDay = widget.budgetCycleStartDay;
    _smsApprovalMode = widget.smsApprovalMode;
    _loadLangPref();
    ThemeService.instance.themeMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted)
      setState(() => _themeMode = ThemeService.instance.themeMode.value);
  }

  Future<void> _loadLangPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'en';
    if (mounted) setState(() => _selectedLang = saved);
  }

  Future<void> _saveLangPref(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    setState(() => _selectedLang = code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Language set to ${_languages.firstWhere((l) => l.code == code).name}. Full support coming soon!',
        ),
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SMS mode set to: ${mode.label}')),
    );
  }

  Future<void> _openSmsApprovalModePicker() async {
    final selected = await showModalBottomSheet<SmsApprovalMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'SMS Auto-Track Approval Mode',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              for (final mode in SmsApprovalMode.values)
                RadioListTile<SmsApprovalMode>(
                  value: mode,
                  groupValue: _smsApprovalMode,
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    Navigator.of(ctx).pop(value);
                  },
                ),
              const SizedBox(height: 8),
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
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Budget Cycle Start Date'),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SmartDateSelector(
              selectedDate: selectedDate,
              onDateSelected: (date) {
                setModalState(() {
                  selectedDate = date;
                });
              },
              label: 'Choose which date your budget cycle should start',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selectedDate),
              child: const Text('Save'),
            ),
          ],
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Budget cycle now starts on day $startDay. $cycleInfo')),
    );
  }

  Future<void> _openBudgetDialog() async {
    final controller = TextEditingController(text: _budget.toString());
    final updated = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly budget',
            prefixText: '₹',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount.')),
                );
                return;
              }
              Navigator.of(ctx).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) {
      final prefs = await SharedPreferences.getInstance();
      final userId = AuthService.instance.currentUser?.id ?? 'guest';
      await prefs.setInt(_budgetPreferenceKey(userId), updated);
      if (!mounted) return;
      setState(() => _budget = updated);
      widget.onBudgetUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Monthly budget updated to ₹$updated')),
      );
    }
  }

  Future<void> _openRentDialog() async {
    final controller = TextEditingController(text: _rent.toString());
    final updated = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Monthly Rent'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly rent',
            prefixText: '₹',
            helperText: 'Set 0 if not applicable (hostel with included rent).',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount.')),
                );
                return;
              }
              Navigator.of(ctx).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) {
      final prefs = await SharedPreferences.getInstance();
      final userId = AuthService.instance.currentUser?.id ?? 'guest';
      await prefs.setInt(_rentPreferenceKey(userId), updated);
      if (!mounted) return;
      setState(() => _rent = updated);
      widget.onRentUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Monthly rent updated to ₹$updated')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be signed out of PocketPilot.'),
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
        title: const Text('Delete account?'),
        content: const Text(
          'This action is permanent. Your account sign-in will be removed and you may lose synced cloud data.',
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
            child: const Text('Delete'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.instance.userMessageFor(
              error,
              isRegistration: false,
            ),
          ),
        ),
      );
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Profile Header ──────────────────────────────────────────
          Container(
            color: colorScheme.primaryContainer.withOpacity(0.35),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Appearance ──────────────────────────────────────────────
          const _SectionHeader(label: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Mode',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
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
          ),

          // ── Language ─────────────────────────────────────────────────
          const _SectionHeader(label: 'Language'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.map((lang) {
                final isSelected = _selectedLang == lang.code;
                return ChoiceChip(
                  avatar: Text(lang.flag, style: const TextStyle(fontSize: 16)),
                  label: Text(lang.name),
                  selected: isSelected,
                  onSelected: (_) => _saveLangPref(lang.code),
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'More languages coming soon',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // ── SMS Tracking ─────────────────────────────────────────────
          const _SectionHeader(label: 'SMS Tracking'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.tertiaryContainer,
              child: Icon(
                Icons.sms_rounded,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            title: const Text('Auto-Track Approval Mode'),
            subtitle: Text(_smsApprovalMode.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _smsApprovalMode.label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: _openSmsApprovalModePicker,
          ),

          // ── Budget & Rent ────────────────────────────────────────────
          const _SectionHeader(label: 'Budget & Rent'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.edit_note_rounded,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('Monthly Budget'),
            subtitle: Text(
              '₹$_budget per month',
              style: TextStyle(color: colorScheme.primary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openBudgetDialog,
          ),
          const Divider(indent: 72, height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.home_work_rounded,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('Monthly Rent'),
            subtitle: Text(
              _rent == 0 ? 'Not applicable (₹0)' : '₹$_rent per month',
              style: TextStyle(color: colorScheme.secondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openRentDialog,
          ),
          const Divider(indent: 72, height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.calendar_month_rounded,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('Budget Cycle Start'),
            subtitle: Text(
              'Day $_budgetCycleStartDay of every month',
              style: TextStyle(color: colorScheme.tertiary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openBudgetCycleDialog,
          ),

          // ── Account ──────────────────────────────────────────────────
          const _SectionHeader(label: 'Account'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.logout_rounded, color: colorScheme.error),
                label: Text(
                  'Log out',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Delete Account'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _LangOption {
  const _LangOption(this.name, this.code, this.flag);
  final String name;
  final String code;
  final String flag;
}
