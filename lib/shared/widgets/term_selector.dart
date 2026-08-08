import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/term_controller.dart';

class TermSelector extends StatelessWidget {
  const TermSelector({super.key});

  Future<void> _showNewTermDialog(BuildContext context) async {
    final controller = context.read<TermController>();
    final nameCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Term name',
                hintText: 'e.g. 1st Sem 2026-2027',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yearCtrl,
              decoration: const InputDecoration(
                labelText: 'School year',
                hintText: 'e.g. 2026-2027',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              controller.createTerm(nameCtrl.text.trim(), yearCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTerm(BuildContext context, String termId, String termName) async {
    final controller = context.read<TermController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete term?'),
        content: Text(
          'This will permanently delete "$termName" along with all its classes and grades. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteTerm(termId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TermController>();

    if (controller.loading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.terms.isNotEmpty)
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: controller.selectedTermId,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              items: controller.terms
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) controller.selectTerm(id);
              },
            ),
          )
        else
          const Text('No terms yet', style: TextStyle(color: Colors.grey)),
        if (controller.selectedTerm != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete term',
            onPressed: () => _confirmDeleteTerm(
              context,
              controller.selectedTerm!.id,
              controller.selectedTerm!.name,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'New term',
          onPressed: () => _showNewTermDialog(context),
        ),
      ],
    );
  }
}