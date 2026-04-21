import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Hero of the report. One sentence from GPT-4o, screenshot-worthy.
/// This is the line the user forwards to a friend. It has to hit.
class VerdictCard extends StatelessWidget {
  final String verdict;
  final int score;
  final String tier;
  final String archetype;

  const VerdictCard({
    super.key,
    required this.verdict,
    required this.score,
    required this.tier,
    required this.archetype,
  });

  @override
  Widget build(BuildContext context) {
    if (verdict.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            AppColors.red.withValues(alpha: 0.10),
            AppColors.surface1,
          ],
        ),
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withValues(alpha: 0.12),
            blurRadius: 28, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THE VERDICT',
                style: AppTypography.label.copyWith(
                  color: AppColors.red, letterSpacing: 3.2, fontSize: 9)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.65), width: 0.8),
                ),
                child: Text('$score · ${tier.toUpperCase()}',
                  style: AppTypography.label.copyWith(
                    color: AppColors.red, letterSpacing: 2.0, fontSize: 10,
                    fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          Text(
            verdict,
            style: AppTypography.h1Italic.copyWith(
              fontSize: 22,
              color: AppColors.textPrimary,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 12,
                color: AppColors.red.withValues(alpha: 0.75)),
              const SizedBox(width: 6),
              Text(archetype.toUpperCase(),
                style: AppTypography.label.copyWith(
                  color: AppColors.red.withValues(alpha: 0.9),
                  letterSpacing: 2.4, fontSize: 9,
                  fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 500.ms)
      .slideY(begin: 0.04, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}
