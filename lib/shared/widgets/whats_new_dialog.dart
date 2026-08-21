import 'package:flutter/material.dart';
import 'package:university_companion_app/shared/theme/app_theme.dart';
import 'package:university_companion_app/shared/services/whats_new_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA — edit this every release
// ─────────────────────────────────────────────────────────────────────────────

/// The version string shown in the dialog header.
/// Update this to match your pubspec.yaml version when you release.
const String _kCurrentVersionLabel = '2.2.12';

/// The list of changes shown in the dialog.
/// Replace/add entries here every release.
///
/// NOTE: Cannot be `const` because AppColors values (navyDark, excellent, etc.)
/// are `static const` fields on a non-const class, which Dart doesn't allow in
/// a top-level const list. Use a plain final list instead.
final List<_WhatsNewEntry> _kEntries = [
  _WhatsNewEntry(
    icon: Icons.dark_mode_outlined,
    color: const Color(0xFF8B5CF6),
    title: 'Dark Mode',
    description:
        'Your eyes will thank you. Switch between Light, Dark, and Auto in Settings → Appearance. (Dark mode is not fully finished yet, but I am working on it!)',
  ),
  _WhatsNewEntry(
    icon: Icons.schedule_rounded,
    color: AppColors.navyDark,
    title: 'Current Time Line',
    description:
        'A red line now marks the current time on your weekly schedule so you always know where you are in your day.',
  ),
  _WhatsNewEntry(
    icon: Icons.auto_awesome_rounded,
    color: AppColors.excellent,
    title: 'Reviewer & Quiz Generator',
    description:
        'Paste notes or upload PDFs and let AI generate a practice quiz. Supports Multiple Choice, True/False, Identification, Fill in the Blanks, and Enumeration.',
  ),
  _WhatsNewEntry(
    icon: Icons.assignment_outlined,
    color: AppColors.overdue,
    title: 'Tasks & Reminders',
    description:
        'Track assignments, exams, and projects with due-date reminders. Overdue tasks now surface right on the Home screen.',
  ),
  _WhatsNewEntry(
    icon: Icons.notifications_outlined,
    color: AppColors.passingWarn,
    title: 'Notification Preferences',
    description:
        'Choose how early to be reminded before class (15 min, 30 min, or 1 hour) and before task deadlines (1–3 days).',
  ),
  _WhatsNewEntry(
    icon: Icons.home_rounded,
    color: const Color(0xFF4A6FA5),
    title: 'Refreshed Home Screen',
    description:
        'Meet Koko, your campus mascot! The Home screen now shows urgent tasks, a live notification bell, and quick-action shortcuts.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the What's New dialog if this version hasn't been seen yet.
/// Call this from [AuthGate] after the user is authenticated.
Future<void> showWhatsNewIfNeeded(BuildContext context) async {
  final should = await WhatsNewService.shouldShow();
  if (!should) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WhatsNewDialog(),
  );

  await WhatsNewService.markSeen();
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _WhatsNewDialog extends StatefulWidget {
  const _WhatsNewDialog();

  @override
  State<_WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<_WhatsNewDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Gradient header ──────────────────────────────────────
                const _Header(version: _kCurrentVersionLabel),

                // ── Scrollable entries ───────────────────────────────────
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    shrinkWrap: true,
                    itemCount: _kEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _EntryRow(entry: _kEntries[i]),
                  ),
                ),

                // ── Footer ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Let's go!"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String version;
  const _Header({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.new_releases_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's New",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Version $version',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Here's what I added and improved in this release.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE ENTRY ROW
// ─────────────────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final _WhatsNewEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(entry.icon, color: entry.color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                entry.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _WhatsNewEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _WhatsNewEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}