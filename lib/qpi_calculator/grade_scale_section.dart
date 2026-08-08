import 'package:flutter/material.dart';
import '../shared/models/grade_scale.dart';
import '../shared/theme/app_theme.dart';

class GradeScaleSection extends StatelessWidget {
  final GradeScale scale;
  const GradeScaleSection({super.key, this.scale = defaultGradeScale});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.pillLavender,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.list_alt_rounded, color: AppColors.navyDark, size: 18),
        ),
        title: Text('Grade Scale — ${scale.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          scale.lowerIsBetter ? 'Lower is better' : 'Higher is better',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: scale.entries.map((e) {
                final tier = standingFor(e.points, scale).tier;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.forTier(tier),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        e.points.toStringAsFixed(2),
                        style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}