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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final firstName = user?.email != null ? user!.email!.split('@').first : 'there';
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
            Row(
              children: [
                Text(
                  'Hi, $firstName',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, color: AppColors.navyMid, size: 22),
              ],
            ),
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

class _TopBar extends StatelessWidget {
  final VoidCallback onLogout;
  const _TopBar({required this.onLogout});

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
                  leading: const Icon(Icons.person_outline_rounded, color: AppColors.navyDark),
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
                  leading: SvgPicture.asset(
                    'lib/images/logout.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(AppColors.overdue, BlendMode.srcIn),
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
                    onLogout();
                  },
                ),
              ]),
            ),
          ),
        ),
        const Text(
          'University Companion',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.navyDark,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: AppColors.textDark, size: 22),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.pillLavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.navyDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(school, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const Icon(Icons.verified_rounded, color: AppColors.navyMid, size: 20),
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
    final todayCode = dayCodes[now.weekday - 1];
    final nowMinutes = now.hour * 60 + now.minute;

    final todays = classes.where((c) => c.day == todayCode).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final ongoing = todays.where((c) => c.startMinutes <= nowMinutes && nowMinutes < c.endMinutes);
    final upcoming = todays.where((c) => c.startMinutes > nowMinutes);
    final current = ongoing.isNotEmpty ? ongoing.first : null;
    final next = current ?? (upcoming.isNotEmpty ? upcoming.first : null);
    final statusLabel = current != null ? 'IN CLASS' : 'FREE TIME';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(28)),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -6,
            child: Icon(Icons.graphic_eq_rounded, size: 90, color: Colors.white.withOpacity(0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                next == null
                    ? 'No more classes today'
                    : current != null
                        ? 'Ends at ${next.endTime}'
                        : 'Next class ${next.startTime}',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                next == null ? 'Enjoy your day!' : 'Next: ${next.subjectCode}',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
              ),
              if (next != null) ...[
                const SizedBox(height: 20),
                _HeroChip(icon: Icons.access_time_rounded, label: '${next.startTime} - ${next.endTime}'),
                if (next.room.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _HeroChip(icon: Icons.door_front_door_outlined, label: next.room),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(28)),
      child: const Text(
        'Create a term to see your schedule here.',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
    final todayCode = dayCodes[now.weekday - 1];
    final nowMinutes = now.hour * 60 + now.minute;

    final items = (classes.where((c) => c.day == todayCode && c.startMinutes > nowMinutes).toList()
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
                decoration: BoxDecoration(color: AppColors.pillLavender, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calendar_month_rounded, color: AppColors.navyDark, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Classes", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Rest of the day', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text('Nothing else scheduled today.', style: TextStyle(color: AppColors.textMuted))
          else
            ...items.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: c.colorValue, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.schedule_rounded, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.subjectCode, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${c.startTime} - ${c.endTime}${c.room.isNotEmpty ? ' · ${c.room}' : ''}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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