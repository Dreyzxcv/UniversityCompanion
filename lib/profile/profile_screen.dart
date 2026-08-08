import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/app_user.dart';
import '../shared/services/auth_service.dart';
import '../shared/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: user == null
          ? const Center(child: Text('Not signed in.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestoreDocStream(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!.data();
                if (data == null) {
                  return const Center(child: Text('Profile not found.'));
                }
                final appUser = AppUser.fromMap(user.uid, data);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _ProfileHeader(appUser: appUser),
                    const SizedBox(height: 24),
                    _SectionLabel('Account Details'),
                    const SizedBox(height: 10),
                    _InfoCard(
                      children: [
                        _InfoRow(icon: Icons.badge_outlined, label: 'Full name', value: appUser.name),
                        const _InfoDivider(),
                        _InfoRow(icon: Icons.account_balance_rounded, label: 'School', value: appUser.school),
                        const _InfoDivider(),
                        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: appUser.email),
                        const _InfoDivider(),
                        _InfoRow(
                          icon: appUser.verified ? Icons.verified_rounded : Icons.error_outline_rounded,
                          iconColor: appUser.verified ? AppColors.excellent : AppColors.passingWarn,
                          label: 'Email status',
                          value: appUser.verified ? 'Verified' : 'Not verified yet',
                        ),
                      ],
                    ),
                    if (!appUser.verified) ...[
                      const SizedBox(height: 10),
                      _ResendVerificationButton(auth: auth),
                    ],
                    const SizedBox(height: 24),
                    _SectionLabel('Manage Account'),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      label: 'Edit name & school',
                      onTap: () => _openEditSheet(context, auth, appUser),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.lock_reset_rounded,
                      label: 'Change password',
                      subtitle: 'We\'ll email you a reset link',
                      onTap: () => _sendPasswordReset(context, auth, appUser.email),
                    ),
                    const SizedBox(height: 24),
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      isDestructive: true,
                      onTap: () => _confirmLogout(context, auth),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _openEditSheet(BuildContext context, AuthService auth, AppUser current) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(auth: auth, current: current),
    );
  }

  Future<void> _sendPasswordReset(BuildContext context, AuthService auth, String email) async {
    try {
      await auth.sendPasswordReset(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text('Password reset link sent to $email.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again to access your schedule and QPI records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await auth.logOut();
    }
  }
}

/// Small helper so the StreamBuilder above doesn't need a direct Firestore
/// import cluttering the widget's build method.
Stream<DocumentSnapshot<Map<String, dynamic>>> FirebaseFirestoreDocStream(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
}

class _ProfileHeader extends StatelessWidget {
  final AppUser appUser;
  const _ProfileHeader({required this.appUser});

  String get _initials {
    final trimmed = appUser.name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                _initials,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            appUser.name.isEmpty ? 'Unnamed Student' : appUser.name,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          if (appUser.school.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              appUser.school,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: appUser.verified ? AppColors.excellent : AppColors.passingWarn,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  appUser.verified ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  appUser.verified ? 'Verified Account' : 'Verification Pending',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
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
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.3),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: AppColors.cardBorder, indent: 56, endIndent: 16);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.pillLavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor ?? AppColors.navyDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.overdue : AppColors.navyDark;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDestructive ? AppColors.overdue.withOpacity(0.1) : AppColors.pillLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendVerificationButton extends StatefulWidget {
  final AuthService auth;
  const _ResendVerificationButton({required this.auth});

  @override
  State<_ResendVerificationButton> createState() => _ResendVerificationButtonState();
}

class _ResendVerificationButtonState extends State<_ResendVerificationButton> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await widget.auth.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Check your inbox.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send verification email. Try again later.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _sending ? null : _resend,
      icon: _sending
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.mark_email_unread_outlined),
      label: Text(_sending ? 'Sending…' : 'Resend verification email'),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final AuthService auth;
  final AppUser current;
  const _EditProfileSheet({required this.auth, required this.current});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _schoolCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.current.name);
    _schoolCtrl = TextEditingController(text: widget.current.school);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.auth.updateProfile(
        name: _nameCtrl.text.trim(),
        school: _schoolCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schoolCtrl,
              decoration: const InputDecoration(labelText: 'School / University'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}