import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/face_geometry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'measurement_grid.dart';

/// Collapsed-by-default deep-dive. The nerd / credibility layer — users tap
/// to expand, see the full 16-metric grid. NOT the main UX. This is the
/// "measured, not guessed" proof that sits behind the main experience.
class HiddenDepthPanel extends StatefulWidget {
  final FaceGeometry geometry;
  const HiddenDepthPanel({super.key, required this.geometry});

  @override
  State<HiddenDepthPanel> createState() => _HiddenDepthPanelState();
}

class _HiddenDepthPanelState extends State<HiddenDepthPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(Rd.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.md, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(Rd.lg),
                border: Border.all(
                  color: AppColors.measure.withValues(alpha: 0.26),
                  width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.measure.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.measure.withValues(alpha: 0.55),
                        width: 0.8),
                    ),
                    child: const Icon(Icons.data_usage_rounded,
                      size: 16, color: AppColors.measure),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SEE FULL BREAKDOWN',
                          style: AppTypography.label.copyWith(
                            color: AppColors.measure,
                            letterSpacing: 2.6, fontSize: 10)),
                        const SizedBox(height: 3),
                        Text('All 16 measurements · every angle, every ratio',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11.5, height: 1.3)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: const Icon(Icons.expand_more_rounded,
                      color: AppColors.measure, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expanded content — the full measurement grid, animated in
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MeasurementGrid(g: widget.geometry)
                    .animate().fadeIn(duration: 240.ms),
                )
              : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
