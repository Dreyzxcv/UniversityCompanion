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
import '../../tasks/add_task_sheet.dart';
import '../../schedule/class_form_screen.dart';
import '../models/task_item.dart';

class HomeScreen extends StatelessWidget {
  /// Callback to switch the bottom nav tab (0=Home,1=Schedule,2=Tasks,…)
  final ValueChanged<int>? onSwitchTab;

  const HomeScreen({super.key, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final termController = context.watch<TermController>();
    final firestoreService = context.read<FirestoreService>();
    final termId = termController.selectedTermId;

    return Scaffold(
      body: RefreshIndicator(
        // Pull-to-refresh: the StreamBuilders self-update, so we just need
        // to give Firestore a moment to re-settle before dismissing the indicator.
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 600)),
        color: AppColors.navyDark,
        child: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(), // needed for pull-to-refresh
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              _TopBar(onLogout: auth.logOut, termId: termId, firestoreService: firestoreService),
              const SizedBox(height: 16),

              // Mascot greeting card
              if (user != null)
                termId == null
                    ? _MascotGreetingLoader(
                        uid: user.uid,
                        fallbackEmail: user.email,
                        classes: const [],
                        tasks: const [],
                      )
                    : StreamBuilder<List<ClassSession>>(
                        stream: firestoreService.watchClasses(termId),
                        builder: (context, classSnap) {
                          return StreamBuilder<List<TaskItem>>(
                            stream: firestoreService.watchTasks(termId),
                            builder: (context, taskSnap) {
                              return _MascotGreetingLoader(
                                uid: user.uid,
                                fallbackEmail: user.email,
                                classes: classSnap.data ?? [],
                                tasks: taskSnap.data ?? [],
                              );
                            },
                          );
                        },
                      ),

              const SizedBox(height: 16),

              // School card (taps through to Profile)
              if (user != null) _SchoolCard(uid: user.uid),
              const SizedBox(height: 16),

              // Urgent tasks badge (overdue + due today)
              if (termId != null)
                StreamBuilder<List<TaskItem>>(
                  stream: firestoreService.watchTasks(termId),
                  builder: (context, snapshot) {
                    final tasks = snapshot.data ?? [];
                    final urgent = tasks
                        .where((t) =>
                            !t.isCompleted && (t.isDueToday || t.isOverdue))
                        .toList()
                      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    if (urgent.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        _UrgentTasksCard(tasks: urgent, onSwitchTab: onSwitchTab),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

              // Next class hero (arrow now navigates to Schedule tab)
              termId == null
                  ? const _NoTermHero()
                  : StreamBuilder<List<ClassSession>>(
                      stream: firestoreService.watchClasses(termId),
                      builder: (context, snapshot) {
                        return _NextClassHero(
                          classes: snapshot.data ?? [],
                          onSwitchTab: onSwitchTab,
                        );
                      },
                    ),
              const SizedBox(height: 16),

              // Today's classes — all of them, with past ones dimmed
              if (termId != null)
                StreamBuilder<List<ClassSession>>(
                  stream: firestoreService.watchClasses(termId),
                  builder: (context, snapshot) {
                    return _UpcomingCard(classes: snapshot.data ?? []);
                  },
                ),

                const SizedBox(height: 16),

                // Quick actions row — now below Today's Classes
                _QuickActionsRow(onSwitchTab: onSwitchTab),
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Actions Row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final ValueChanged<int>? onSwitchTab;
  const _QuickActionsRow({this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.pillBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: context.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action tiles
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.assignment_add,
                  label: 'Add Task',
                  accent: AppColors.overdue,
                  accentBg: isDark
                      ? AppColors.overdue.withOpacity(0.15)
                      : const Color(0xFFFFECEB),
                  onTap: () async {
                    final termController = context.read<TermController>();
                    final termId = termController.selectedTermId;
                    if (termId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create a term first.')),
                      );
                      return;
                    }
                    final firestoreService = context.read<FirestoreService>();
                    final classes =
                        await firestoreService.fetchClassesOnce(termId);
                    if (!context.mounted) return;
                    final result =
                        await showAddTaskSheet(context, classes: classes);
                    if (result?.task == null || !context.mounted) return;
                    await firestoreService.addTask(termId, result!.task!);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.calendar_month_rounded,
                  label: 'Add Class',
                  accent: AppColors.navyDark,
                  accentBg: isDark
                      ? AppColorsDark.pillLavender
                      : AppColors.pillLavender,
                  onTap: () async {
                    final termController = context.read<TermController>();
                    final termId = termController.selectedTermId;
                    if (termId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create a term first.')),
                      );
                      return;
                    }
                    final firestoreService = context.read<FirestoreService>();
                    final classes =
                        await firestoreService.fetchClassesOnce(termId);
                    if (!context.mounted) return;
                    final result = await Navigator.push<ClassFormResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClassFormScreen(allClassesInTerm: classes),
                      ),
                    );
                    if (result == null || !context.mounted) return;
                    for (final session in result.sessions) {
                      await firestoreService.addClass(termId, session);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'New Quiz',
                  accent: AppColors.excellent,
                  accentBg: isDark
                      ? AppColors.excellent.withOpacity(0.15)
                      : const Color(0xFFE8F5E9),
                  onTap: () {
                    if (onSwitchTab != null) {
                      onSwitchTab!(3);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Go to the Review tab to create a quiz.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color accentBg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.accentBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Urgent Tasks Card (overdue + due today)
// ---------------------------------------------------------------------------

class _UrgentTasksCard extends StatelessWidget {
  final List<TaskItem> tasks;
  final ValueChanged<int>? onSwitchTab;
  const _UrgentTasksCard({required this.tasks, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSwitchTab?.call(2), // Tasks tab
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.overdue.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.overdue.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.overdue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.overdue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tasks.any((t) => t.isOverdue)
                        ? 'Overdue & Due Today'
                        : 'Due Today',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.overdue,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.overdue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tasks.take(3).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        t.isOverdue
                            ? Icons.cancel_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: AppColors.overdue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.isOverdue ? 'Overdue' : 'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.overdue.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                )),
            if (tasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${tasks.length - 3} more — tap to view all',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.overdue.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mascot greeting loader
// ---------------------------------------------------------------------------

class _MascotGreetingLoader extends StatelessWidget {
  final String uid;
  final String? fallbackEmail;
  final List<ClassSession> classes;
  final List<TaskItem> tasks;

  const _MascotGreetingLoader({
    required this.uid,
    required this.fallbackEmail,
    required this.classes,
    required this.tasks,
  });

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
        final firstName = (fullName != null && fullName.trim().isNotEmpty)
            ? _firstNameFrom(fullName)
            : (fallbackEmail?.split('@').first ?? 'there');
        return _MascotCard(firstName: firstName, classes: classes, tasks: tasks);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Mascot card with idle bounce + contextual speech bubble
// ---------------------------------------------------------------------------

class _MascotCard extends StatefulWidget {
  final String firstName;
  final List<ClassSession> classes;
  final List<TaskItem> tasks;

  const _MascotCard({
    required this.firstName,
    required this.classes,
    required this.tasks,
  });

  @override
  State<_MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends State<_MascotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  // 0 = show context message, 1+ = index into _funMessages
  int _messageIndex = 0;
  bool _showingFun = false;

  static const _funMessages = [
    "Don't forget to review your notes today! 📖",
    "One subject at a time. You've got this! 💪",
    "Take a 5-minute break if you need it. ☕",
    "Consistency beats cramming every time! 🧠",
    "I believe in you more than you believe in yourself. ",
    "Sleep is part of studying too, you know. 🌙",
    "Koko has never failed an exam.",
    "You came this far. Don't stop now. 🏁",
    "Did you drink water today? Hydration = brain power! 💧",
    "Your future self will thank you for studying now. ✨",
    "Grades don't define you, but effort does. 🌱",
    "Pro tip: rewriting notes = better retention! ✍️",
    "Koko is rooting for you. Always. 🐾",
    "Hard days are part of the journey too. 🌤️",
    "You're doing better than you think. Keep going! 💖",
  ];

  String get _currentMessage {
    if (!_showingFun) return _contextMessage;
    return _funMessages[_messageIndex % _funMessages.length];
  }

  void _onBubbleTap() {
    setState(() {
      if (!_showingFun) {
        _showingFun = true;
        _messageIndex = 0;
      } else {
        _messageIndex = (_messageIndex + 1) % _funMessages.length;
      }
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _contextMessage {
    final now = DateTime.now();
    const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayCode = dayCodes[now.weekday - 1];
    final nowMinutes = now.hour * 60 + now.minute;

    final todays = widget.classes
        .where((c) => c.day == todayCode)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final ongoing = todays.where(
      (c) => c.startMinutes <= nowMinutes && nowMinutes < c.endMinutes,
    );
    final upcoming = todays.where((c) => c.startMinutes > nowMinutes);

    final urgentTasks = widget.tasks
        .where((t) => !t.isCompleted && (t.isDueToday || t.isOverdue))
        .toList();
    final overdueCount = urgentTasks.where((t) => t.isOverdue).length;
    final todayCount =
        urgentTasks.where((t) => t.isDueToday && !t.isOverdue).length;

    String taskNote = '';
    if (overdueCount > 0 && todayCount > 0) {
      taskNote = '\n$overdueCount overdue, $todayCount due today! 📋';
    } else if (overdueCount > 0) {
      taskNote =
          '\n$overdueCount task${overdueCount > 1 ? 's' : ''} overdue! 📋';
    } else if (todayCount > 0) {
      taskNote =
          '\n$todayCount task${todayCount > 1 ? 's' : ''} due today. 📋';
    }

    if (ongoing.isNotEmpty) {
      final c = ongoing.first;
      return "You're in ${c.subjectCode} right now.\nStay focused! 📚$taskNote";
    }
    if (upcoming.isNotEmpty) {
      final c = upcoming.first;
      final mins = c.startMinutes - nowMinutes;
      if (mins <= 15) {
        return "${c.subjectCode} starts in $mins min!\nTime to head out! 🏃$taskNote";
      }
      if (mins <= 60) {
        return "Next: ${c.subjectCode} at ${c.startTime}.\nYou've got time! ✨$taskNote";
      }
      return "Next class is ${c.subjectCode}.\nRelax a bit first~ 😌$taskNote";
    }
    if (todays.isNotEmpty) {
      return "All done for today!\nRest up and recharge. 🌙$taskNote";
    }

    if (taskNote.isNotEmpty) {
      if (overdueCount > 0)
        return "Heads up! You have $overdueCount overdue task${overdueCount > 1 ? 's' : ''}.\nBetter get to it! 📋";
      return "You have $todayCount task${todayCount > 1 ? 's' : ''} due today.\nGood luck! 📋";
    }

    final hour = now.hour;
    if (hour < 12) return "No classes today!\nA great day to review. 📖";
    if (hour < 17) return "Free afternoon!\nPerfect study time. ☕";
    return "No classes today!\nEnjoy your evening~ 🌟";
  }

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 20,
                color: context.textPrimary,
                fontWeight: FontWeight.w400,
                fontFamily: 'Roboto',
              ),
              children: [
                TextSpan(text: '$_greeting, '),
                TextSpan(
                  text: '${widget.firstName}!',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: context.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _bounceAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _bounceAnim.value),
                    child: child,
                  );
                },
                child: _MascotFigure(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SpeechBubble(
                  message: _currentMessage,
                  showingFun: _showingFun,
                  funIndex: _messageIndex,
                  totalFun: _funMessages.length,
                  onTap: _onBubbleTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mascot figure
// ---------------------------------------------------------------------------

class _MascotFigure extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: -6,
          left: 10,
          right: 10,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyDark.withOpacity(0.18),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEEF0FF), AppColors.pillLavender],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.navyDark.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset('lib/images/kokoWhite.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Speech bubble
// ---------------------------------------------------------------------------

class _SpeechBubble extends StatelessWidget {
  final String message;
  final bool showingFun;
  final int funIndex;
  final int totalFun;
  final VoidCallback onTap;

  const _SpeechBubble({
    required this.message,
    required this.showingFun,
    required this.funIndex,
    required this.totalFun,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.pillLavender,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border:
                  Border.all(color: AppColors.navyDark.withOpacity(0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.navyDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Koko says',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyDark,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    // Dot indicators when cycling fun messages
                    if (showingFun) ...[
                      ...List.generate(
                        totalFun.clamp(0, 5), // max 5 dots shown
                        (i) => Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(left: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == funIndex % 5
                                ? AppColors.navyDark
                                : AppColors.navyDark.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: AppColors.navyDark.withOpacity(0.35),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -9,
          top: 18,
          child: CustomPaint(
            size: const Size(10, 14),
            painter: _BubbleTailPainter(),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = AppColors.pillLavender
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fillPaint);
    final borderPaint = Paint()
      ..color = AppColors.navyDark.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------------------
// Top bar with notification bell badge
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final VoidCallback onLogout;
  final String? termId;
  final FirestoreService? firestoreService;

  const _TopBar({
    required this.onLogout,
    this.termId,
    this.firestoreService,
  });

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
                child: const Icon(Icons.logout_rounded, color: AppColors.overdue, size: 26),
              ),
              const SizedBox(height: 16),
              const Text('Log out?',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                'You\'ll need to sign in again to access your schedule and QPI records.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
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
                      style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
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
    if (confirmed == true) await auth.logOut();
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
                  leading: const Icon(Icons.person_outline_rounded, color: AppColors.navyDark),
                  title: const Text('My Profile',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: AppColors.navyDark),
                  title: const Text('Settings',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                  onTap: () {
                    Navigator.pop(context);
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
                          child: const SettingsScreen(),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: SvgPicture.asset('lib/images/logout.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(AppColors.overdue, BlendMode.srcIn)),
                  title: const Text('Log out',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.overdue)),
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
        // Notification bell with badge
        termId != null && firestoreService != null
            ? _NotificationBell(termId: termId!, firestoreService: firestoreService!)
            : _RoundIconButton(
                icon: Icons.notifications_none_rounded,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications')),
                ),
              ),
      ],
    );
  }
}

/// Bell icon that shows a red count badge for overdue tasks + classes
/// starting within 60 minutes. Tapping it pops a summary sheet.
class _NotificationBell extends StatelessWidget {
  final String termId;
  final FirestoreService firestoreService;

  const _NotificationBell({
    required this.termId,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskItem>>(
      stream: firestoreService.watchTasks(termId),
      builder: (context, taskSnap) {
        return StreamBuilder<List<ClassSession>>(
          stream: firestoreService.watchClasses(termId),
          builder: (context, classSnap) {
            final tasks = taskSnap.data ?? [];
            final classes = classSnap.data ?? [];

            final now = DateTime.now();
            const dayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
            final todayCode = dayCodes[now.weekday - 1];
            final nowMinutes = now.hour * 60 + now.minute;

            // Overdue tasks
            final overdueTasks = tasks
                .where((t) => !t.isCompleted && t.isOverdue)
                .toList();
            // Due today (not overdue)
            final todayTasks = tasks
                .where((t) => !t.isCompleted && t.isDueToday && !t.isOverdue)
                .toList();
            // Classes starting in <= 60 min
            final upcomingClasses = classes
                .where((c) =>
                    c.day == todayCode &&
                    c.startMinutes > nowMinutes &&
                    c.startMinutes - nowMinutes <= 60)
                .toList()
              ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

            final badgeCount = overdueTasks.length + todayTasks.length + upcomingClasses.length;

            return GestureDetector(
              onTap: () => _showNotificationSheet(
                context,
                overdueTasks: overdueTasks,
                todayTasks: todayTasks,
                upcomingClasses: upcomingClasses,
                nowMinutes: nowMinutes,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.cardBorderColor),
                    ),
                    child: Icon(
                      badgeCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      color: context.textPrimary,
                      size: 22,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.overdue,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationSheet(
    BuildContext context, {
    required List<TaskItem> overdueTasks,
    required List<TaskItem> todayTasks,
    required List<ClassSession> upcomingClasses,
    required int nowMinutes,
  }) {
    final hasAny = overdueTasks.isNotEmpty || todayTasks.isNotEmpty || upcomingClasses.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              if (!hasAny)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.excellent, size: 40),
                        SizedBox(height: 10),
                        Text('You\'re all caught up!',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                        SizedBox(height: 4),
                        Text('No urgent tasks or upcoming classes.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else ...[
                if (overdueTasks.isNotEmpty) ...[
                  _NotifSectionLabel('Overdue', AppColors.overdue),
                  ...overdueTasks.take(3).map((t) => _NotifTaskTile(task: t, isOverdue: true)),
                  if (overdueTasks.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('+${overdueTasks.length - 3} more overdue',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ),
                ],
                if (todayTasks.isNotEmpty) ...[
                  _NotifSectionLabel('Due Today', AppColors.passingWarn),
                  ...todayTasks.take(3).map((t) => _NotifTaskTile(task: t, isOverdue: false)),
                ],
                if (upcomingClasses.isNotEmpty) ...[
                  _NotifSectionLabel('Starting Soon', AppColors.navyMid),
                  ...upcomingClasses.map((c) {
                    final mins = c.startMinutes - nowMinutes;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: c.colorValue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textDark),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${c.subjectCode} in $mins min',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Text(c.startTime,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifSectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _NotifSectionLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4),
      ),
    );
  }
}

class _NotifTaskTile extends StatelessWidget {
  final TaskItem task;
  final bool isOverdue;
  const _NotifTaskTile({required this.task, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final color = isOverdue ? AppColors.overdue : AppColors.passingWarn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(task.type.icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            isOverdue ? 'Overdue' : 'Today',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
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

// ---------------------------------------------------------------------------
// School card — taps through to Profile
// ---------------------------------------------------------------------------

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
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
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
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: context.textPrimary)),
                ),
                const Icon(Icons.verified_rounded, color: AppColors.navyMid, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Next class hero — arrow navigates to Schedule tab; status includes "DONE FOR TODAY"
// ---------------------------------------------------------------------------

class _NextClassHero extends StatelessWidget {
  final List<ClassSession> classes;
  final ValueChanged<int>? onSwitchTab;

  const _NextClassHero({required this.classes, this.onSwitchTab});

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

    // Status pill label:
    //  - IN CLASS: a class is happening right now
    //  - DONE FOR TODAY: all today's classes are finished
    //  - FREE TIME: no classes today, or before the first one
    final String statusLabel;
    if (current != null) {
      statusLabel = 'IN CLASS';
    } else if (todays.isNotEmpty && upcoming.isEmpty) {
      statusLabel = 'DONE FOR TODAY';
    } else {
      statusLabel = 'FREE TIME';
    }

    return GestureDetector(
      onTap: () => onSwitchTab?.call(1), // Navigate to Schedule tab
      child: Container(
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusLabel == 'DONE FOR TODAY'
                                  ? AppColors.excellent
                                  : Colors.white,
                            ),
                          ),
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
                    // Tappable arrow that navigates to Schedule
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  next == null
                      ? (todays.isNotEmpty ? 'All classes done!' : 'No classes today')
                      : current != null
                          ? 'Ends at ${formatTimeOfDay(next.endTime, is24Hour: is24Hour)}'
                          : 'Next class ${formatTimeOfDay(next.startTime, is24Hour: is24Hour)}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? (todays.isNotEmpty ? 'Rest up! You earned it. 🌙' : 'Enjoy your day!')
                      : 'Next: ${next.subjectCode}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
                ),
                if (next != null) ...[
                  const SizedBox(height: 20),
                  _HeroChip(
                      icon: Icons.access_time_rounded,
                      label: formatTimeRange(next.startTime, next.endTime,
                          is24Hour: is24Hour)),
                  if (next.room.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _HeroChip(icon: Icons.door_front_door_outlined, label: next.room),
                  ],
                ],
              ],
            ),
          ],
        ),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's Classes — all classes, past ones dimmed with strikethrough
// ---------------------------------------------------------------------------

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

    final items = classes
        .where((c) => c.day == todayCode)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.cardBorderColor),
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
                    color: context.pillBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.calendar_month_rounded,
                    color: context.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Classes",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: context.textPrimary)),
                  Text('Full day overview',
                      style: TextStyle(color: context.textSecondary, fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (items.where((c) => c.endMinutes > nowMinutes).isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.navyDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.where((c) => c.endMinutes > nowMinutes).length} left',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text('Nothing scheduled today.',
                style: TextStyle(color: context.textSecondary))
          else
            ...items.map((c) {
              final isPast = c.endMinutes <= nowMinutes;
              final isOngoing = c.startMinutes <= nowMinutes && nowMinutes < c.endMinutes;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  opacity: isPast ? 0.45 : 1.0,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isPast
                              ? Colors.grey.shade300
                              : isOngoing
                                  ? AppColors.excellent
                                  : c.colorValue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPast
                              ? Icons.check_rounded
                              : isOngoing
                                  ? Icons.play_arrow_rounded
                                  : Icons.schedule_rounded,
                          size: 18,
                          color: isPast
                              ? Colors.grey.shade600
                              : isOngoing
                                  ? Colors.white
                                  : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.subjectCode,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isPast
                                    ? context.textSecondary
                                    : context.textPrimary,
                                decoration: isPast
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              '${formatTimeRange(c.startTime, c.endTime, is24Hour: is24Hour)}${c.room.isNotEmpty ? ' · ${c.room}' : ''}',
                              style: TextStyle(
                                  color: context.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isOngoing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.excellent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Now',
                            style: TextStyle(
                              color: AppColors.excellent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else if (isPast)
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.excellent.withOpacity(0.6), size: 16),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unused legacy widget kept to avoid breaking any existing references
// ---------------------------------------------------------------------------

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
            const Icon(Icons.verified_rounded, color: AppColors.navyMid, size: 22),
          ],
        );
      },
    );
  }
}