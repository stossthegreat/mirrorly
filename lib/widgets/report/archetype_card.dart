import 'package:flutter/material.dart';
import '../../services/archetype_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Editorial archetype match card — top-1 result with match %, tagline,
/// and 2-line story. Structured like a museum object label.
class ArchetypeCard extends StatelessWidget {
  final ArchetypeMatch match;
  final VoidCallback? onExpand;

  const ArchetypeCard({super.key, required this.match, this.onExpand});

  @override
  Widget build(BuildContext context) {
    final pct = (match.match * 100).round();
    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.circular(Rd.xl),
      child: Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(Rd.xl),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ARCHETYPE MATCH',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accent, letterSpacing: 2.8, fontSize: 9)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$pct %',
                    style: AppTypography.measurement.copyWith(
                      color: AppColors.accent, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: Sp.md),
            Text(match.archetype.name,
              style: AppTypography.h1.copyWith(
                fontSize: 26,
                color: AppColors.textPrimary,
                letterSpacing: -0.6)),
            const SizedBox(height: 4),
            Text(match.archetype.tagline,
              style: AppTypography.h1Italic.copyWith(
                fontSize: 15,
                color: AppColors.textSecondary,
                letterSpacing: 0.2)),
            const SizedBox(height: Sp.md),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: Sp.md),
            Text(match.archetype.story,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.65,
                fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
