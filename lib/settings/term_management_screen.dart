import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/term.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/term_controller.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/empty_state.dart';

class TermManagementScreen extends StatelessWidget {
  const TermManagementScreen({super.key});

  Future<void> _rename(BuildContext context, FirestoreService service, Term term) async {
    final nameCtrl = TextEditingController(text: term.name);
    final yearCtrl = TextEditingController(text: term.schoolYear);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Term name')),
            const SizedBox(height: 12),
            TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'School year')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await service.renameTerm(term.id, name: nameCtrl.text.trim(), schoolYear: yearCtrl.text.trim());
    }
  }

  Future<void> _confirmDelete(BuildContext context, TermController controller, Term term) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete term?'),
        content: Text(
          'This permanently deletes "${term.name}" along with its classes, grades, and tasks. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.overdue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteTerm(term.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();
    final termController = context.read<TermController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Terms')),
      body: StreamBuilder<List<Term>>(
        stream: service.watchTerms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final terms = snapshot.data ?? [];
          if (terms.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_view_month_rounded,
              title: 'No terms yet',
              message: 'Create a term from the Schedule or QPI screen to see it here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: terms.length,
            itemBuilder: (context, i) {
              final term = terms[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.pillLavender, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.school_rounded, color: AppColors.navyDark, size: 18),
                  ),
                  title: Text(term.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: term.schoolYear.isEmpty ? null : Text(term.schoolYear),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (term.isActive)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(10)),
                          child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.navyDark)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _rename(context, service, term),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.overdue),
                        onPressed: () => _confirmDelete(context, termController, term),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}