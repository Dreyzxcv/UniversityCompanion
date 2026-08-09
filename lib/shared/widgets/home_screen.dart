import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/class_session.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/term_controller.dart';
import '../theme/app_theme.dart';
import '../../profile/profile_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/time_format_controller.dart';
import '../utils/time_format.dart';
import '../../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final termController = context.watch<TermController>();
    final firestoreService = context.read<FirestoreService>();
    final termId = termController.selectedTermId;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _TopBar(onLogout: auth.logOut),
            const SizedBox(height: 20),
            const _DatePill(),
            const SizedBox(height: 16),
            if (user != null) _SchoolCard(uid: user.uid),
            const SizedBox(height: 20),
            if (user != null)
              _GreetingRow(uid: user.uid, fallbackEmail: user.email),
            const SizedBox(height: 20),
            termId == null
                ? const _NoTermHero()
                : StreamBuilder<List<ClassSession>>(
                    stream: firestoreService.watchClasses(termId),
                    builder: (context, snapshot) {
                      return _NextClassHero(classes: snapshot.data ?? []);
                    },
                  ),
            const SizedBox(height: 20),
            if (termId != null)
              StreamBuilder<List<ClassSession>>(
                stream: firestoreService.watchClasses(termId),
                builder: (context, snapshot) {
                  return _UpcomingCard(classes: snapshot.data ?? []);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  final String uid;
  final String? fallbackEmail;
  const _GreetingRow({required this.uid, this.fallbackEmail});

  String _firstNameFrom(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final fullName = snapshot.data?.data()?['name'] as String?;
        final resolvedFirstName =
            (fullName != null && fullName.trim().isNotEmpty)
                ? _firstNameFrom(fullName)
                : (fallbackEmail != null
                    ? fallbackEmail!.split('@').first
                    : 'there');

        return Row(
          children: [
            Text(
              'Hi, $resolvedFirstName',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified_rounded,
                color: AppColors.navyMid, size: 22),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _TopBar({required this.onLogout});

  Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.overdue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.overdue,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log out?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You\'ll need to sign in again to access your schedule and QPI records.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.overdue,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await auth.logOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.menu_rounded,
          onTap: () => showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => SafeArea(
              child: Wrap(children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded,
                      color: AppColors.navyDark),
                  title: const Text(
                    'My Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: AppColors.navyDark),
                  title: const Text(
                    'Settings',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: SvgPicture.asset(
                    'lib/images/logout.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        AppColors.overdue, BlendMode.srcIn),
                  ),
                  title: const Text(
                    'Log out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.overdue,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmLogout(context, context.read<AuthService>());
                  },
                ),
              ]),
            ),
          ),
        ),
        Text(
          'University Companion',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
            letterSpacing: 0.4,
          ),
        ),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new notifications')),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.cardBorderColor),
        ),
        child: Icon(icon, color: context.textPrimary, size: 22),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pillLavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        DateFormat('EEE, MMM d, yyyy').format(DateTime.now()),
        style: const TextStyle(
          color: AppColors.navyDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Reads `users/{uid}.school` directly (rather than adding a new service
/// method) since it's a single one-off read used only for this card.
class _SchoolCard extends StatelessWidget {
  final String uid;
  const _SchoolCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final school = snapshot.data?.data()?['school'] as String?;
        if (school == null || school.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.cardBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.pillBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_balance_rounded, color: context.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(school,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary)),
              ),
              const Icon(Icons.verified_rounded,
                  color: AppColors.navyMid, size: 20),
            ],
          ),
        );
      },
    );
  }
}

/// Mirrors the "FREE TIME / Next class" hero: finds today's current or
/// next class from the already-streamed [classes] list.
class _NextClassHero extends StatelessWidget {
  final List<ClassSession> classes;
  const _NextClassHero({required this.classes});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final is24Hour = context.watch<TimeFormatController>().is24Hour;
    final todayCode = dayCodes[now.weekday - 1];
    final nowMinutes = now.hour * 60 + now.minute;

    final todays = classes.where((c) => c.day == todayCode).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final ongoing = todays.where(
        (c) => c.startMinutes <= nowMinutes && nowMinutes < c.endMinutes);
    final upcoming = todays.where((c) => c.startMinutes > nowMinutes);
    final current = ongoing.isNotEmpty ? ongoing.first : null;
    final next = current ?? (upcoming.isNotEmpty ? upcoming.first : null);
    final statusLabel = current != null ? 'IN CLASS' : 'FREE TIME';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(28)),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -6,
            child: Icon(Icons.graphic_eq_rounded,
                size: 90, color: Colors.white.withOpacity(0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(statusLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white70),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                next == null
                    ? 'No more classes today'
                    : current != null
                        ? 'Ends at ${next.endTime}'
                        : 'Next class ${next.startTime}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                next == null ? 'Enjoy your day!' : 'Next: ${next.subjectCode}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 15),
              ),
              if (next != null) ...[
                const SizedBox(height: 20),
                _HeroChip(
                    icon: Icons.access_time_rounded,
                    label: formatTimeRange(next.startTime, next.endTime,
                        is24Hour: is24Hour)),
                if (next.room.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _HeroChip(
                      icon: Icons.door_front_door_outlined, label: next.room),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NoTermHero extends StatelessWidget {
  const _NoTermHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(28)),
      child: const Text(
        'Create a term to see your schedule here.',
        style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final List<ClassSession> classes;
  const _UpcomingCard({required this.classes});

  @override
  Widget build(BuildContext context) {
    const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final now = DateTime.now();
    final is24Hour = context.watch<TimeFormatController>().is24Hour;
    final todayCode = dayCodes[now.weekday - 1];
    final nowMinutes = now.hour * 60 + now.minute;

    final items = (classes
            .where((c) => c.day == todayCode && c.startMinutes > nowMinutes)
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)))
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.pillLavender,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calendar_month_rounded,
                    color: AppColors.navyDark, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Classes",
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Rest of the day',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('Nothing else scheduled today.',
                style: TextStyle(color: AppColors.textMuted))
          else
            ...items.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: c.colorValue,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.schedule_rounded, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.subjectCode,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                              '${formatTimeRange(c.startTime, c.endTime, is24Hour: is24Hour)}${c.room.isNotEmpty ? ' · ${c.room}' : ''}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
