import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../shared/services/time_format_controller.dart';
import '../shared/services/notification_preferences.dart';
import '../shared/services/theme_mode_controller.dart';
import '../shared/theme/app_theme.dart';
import 'term_management_screen.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/services/schedule_display_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: const [
          _SectionLabel('Preferences'),
          SizedBox(height: 10),
          _TimeFormatCard(),
          SizedBox(height: 12),
          _DarkModeCard(),
          SizedBox(height: 12),
          _ScheduleDisplayCard(),
          SizedBox(height: 24),
          _SectionLabel('Notifications'),
          SizedBox(height: 10),
          _NotificationsCard(),
          SizedBox(height: 24),
          _SectionLabel('Data'),
          SizedBox(height: 10),
          _TermManagementTile(),
          SizedBox(height: 24),
          _SectionLabel('About'),
          SizedBox(height: 10),
          _AppInfoCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _TimeFormatCard extends StatelessWidget {
  const _TimeFormatCard();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TimeFormatController>();
    return _SettingsCard(children: [
      const Text('Time Format', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('Used across your schedule and class times.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      const SizedBox(height: 14),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('12-hour')),
          ButtonSegment(value: true, label: Text('24-hour')),
        ],
        selected: {controller.is24Hour},
        onSelectionChanged: (s) => controller.setIs24Hour(s.first),
      ),
    ]);
  }
}

class _DarkModeCard extends StatelessWidget {
  const _DarkModeCard();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeModeController>();
    return _SettingsCard(children: [
      const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 14),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('Auto')),
        ],
        selected: {controller.mode},
        onSelectionChanged: (s) => controller.setMode(s.first),
      ),
    ]);
  }
}

class _ScheduleDisplayCard extends StatelessWidget {
  const _ScheduleDisplayCard();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleDisplayController>();
    return _SettingsCard(children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Current Time Line', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: const Text('Show the red line marking the current time on your schedule.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        value: controller.showTimeIndicator,
        activeThumbColor: AppColors.navyDark,
        onChanged: controller.setShowTimeIndicator,
      ),
    ]);
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard();

  static const _classOptions = [15, 30, 60];
  static const _taskOptions = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationPreferencesController>();
    final prefs = controller.prefs;

    return _SettingsCard(children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: const Text('Class and task reminders', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        value: prefs.enabled,
        activeThumbColor: AppColors.navyDark,
        onChanged: controller.setEnabled,
      ),
      if (prefs.enabled) ...[
        const Divider(height: 24, color: AppColors.cardBorder),
        const Text('Class reminder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _classOptions.map((m) {
            final label = m < 60 ? '$m min before' : '1 hour before';
            final selected = prefs.classReminderMinutesBefore == m;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => controller.setClassMinutesBefore(m),
              selectedColor: AppColors.navyDark,
              labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
              backgroundColor: AppColors.pillLavender.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('Task due reminder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _taskOptions.map((d) {
            final selected = prefs.taskReminderDaysBefore == d;
            return ChoiceChip(
              label: Text(d == 1 ? '1 day before' : '$d days before'),
              selected: selected,
              onSelected: (_) => controller.setTaskDaysBefore(d),
              selectedColor: AppColors.navyDark,
              labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
              backgroundColor: AppColors.pillLavender.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
            );
          }).toList(),
        ),
      ],
    ]);
  }
}

class _TermManagementTile extends StatelessWidget {
  const _TermManagementTile();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final firestoreService = context.read<FirestoreService>();
          final termController = context.read<TermController>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultiProvider(
                providers: [
                  Provider<FirestoreService>.value(value: firestoreService),
                  ChangeNotifierProvider<TermController>.value(value: termController),
                ],
                child: const TermManagementScreen(),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cardBorder)),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.pillLavender, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calendar_view_month_rounded, color: AppColors.navyDark),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage Terms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('Rename or delete past terms', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  Future<void> _openMail(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'justineandreitacorda@gmail.com',
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        _showNoMailAppMessage(context);
      }
    } catch (_) {
      if (context.mounted) _showNoMailAppMessage(context);
    }
  }

  void _showNoMailAppMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email app found. You can reach me at justineandreitacorda@gmail.com'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(children: [
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final version = snap.data == null
              ? '…'
              : 'v${snap.data!.version} (${snap.data!.buildNumber})';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded, color: AppColors.navyDark),
            title: const Text('Version', style: TextStyle(fontWeight: FontWeight.w700)),
            trailing: Text(version, style: const TextStyle(color: AppColors.textMuted)),
          );
        },
      ),
      const Divider(height: 8, color: AppColors.cardBorder),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.feedback_outlined, color: AppColors.navyDark),
        title: const Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: () => _openMail(context, 'University Companion — Feedback'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.bug_report_outlined, color: AppColors.navyDark),
        title: const Text('Report a Bug', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: () => _openMail(context, 'University Companion — Bug Report'),
      ),
    ]);
  }
}