import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/face_geometry.dart';
import '../../models/mirror_analysis.dart';
import '../../models/scan_record.dart';
import '../../services/archetype_service.dart';
import '../../services/local_store_service.dart';
import '../../services/mirror_api_service.dart';
import '../../services/scoring_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/report/archetype_card.dart';
import '../../widgets/report/score_card.dart';

class ReportScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final FaceGeometry geometry;

  const ReportScreen({
    super.key,
    required this.imageBytes,
    required this.geometry,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  MirrorAnalysis? _analysis;
  String? _error;

  static const _loadingCopy = [
    'Resolving skin micro-texture',
    'Comparing structural archetypes',
    'Locking identity anchors',
    'Rendering maximized composite',
    'Finalizing preserve list',
  ];
  int _copyIdx = 0;

  @override
  void initState() {
    super.initState();
    _rotateCopy();
    _run();
  }

  void _rotateCopy() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _analysis != null) return;
      setState(() => _copyIdx = (_copyIdx + 1) % _loadingCopy.length);
      _rotateCopy();
    });
  }

  Future<void> _run() async {
    try {
      final result = await MirrorApiService.scan(
        imageBytes: widget.imageBytes,
        geometry:   widget.geometry,
      );
      if (mounted) setState(() => _analysis = result);
      // Persist the scan so it lights up Progress + Advisor tabs.
      await _persistScan(result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _persistScan(MirrorAnalysis a) async {
    final score = ScoringService.compute(widget.geometry);
    final match = ArchetypeService.bestMatch(widget.geometry);
    final record = ScanRecord(
      id:                 'scan-${DateTime.now().millisecondsSinceEpoch}',
      takenAt:            DateTime.now(),
      geometry:           widget.geometry,
      score:              score.value,
      tierLabel:          score.tierLabel,
      archetypeName:      match.archetype.name,
      archetypeMatchPct:  (match.match * 100).round(),
      capturedImagePath:  null,
      maximizedImageUrl:  a.maximizedImageUrl,
    );
    await LocalStoreService.saveScan(record);

    // Also save the Flux twin into the Generation Vault so it shows up in the
    // gallery on the Progress tab.
    if (a.maximizedImageUrl.isNotEmpty) {
      await LocalStoreService.saveGeneration(GenerationRecord(
        id:            'gen-${DateTime.now().millisecondsSinceEpoch}',
        createdAt:     DateTime.now(),
        prompt:        'Maximized twin · ${match.archetype.name}',
        imageUrl:      a.maximizedImageUrl,
        relatedScanId: record.id,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: _analysis == null
            ? _buildLoading()
            : _buildReport(_analysis!),
      ),
    );
  }

  Widget _buildLoading() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scan failed', style: AppTypography.h3.copyWith(
                color: AppColors.signalRed)),
              const SizedBox(height: 12),
              Text(_error!, style: AppTypography.bodySmall,
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () { setState(() => _error = null); _run(); },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44, height: 44,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          Text(_loadingCopy[_copyIdx].toUpperCase(),
            key: ValueKey(_copyIdx),
            style: AppTypography.label.copyWith(
              color: AppColors.measure, letterSpacing: 2.5, fontSize: 11)),
          const SizedBox(height: 6),
          Text('Identity anchored. ${_loadingCopy.length} layers compiling.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11, color: AppColors.textTertiary)),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildReport(MirrorAnalysis a) {
    final score = ScoringService.compute(widget.geometry);
    final match = ArchetypeService.bestMatch(widget.geometry);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('THE COMPOSITE', style: AppTypography.label.copyWith(
            color: AppColors.textTertiary, letterSpacing: 2.5))
            .animate().fadeIn(duration: 400.ms),
          const SizedBox(height: Sp.xs),
          Text('Your face, measured.', style: AppTypography.h1)
            .animate().fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: Sp.xl),

          // ── Hero: Aesthetic Index score ─────────────────────────────────
          ScoreCard(score: score)
            .animate().fadeIn(delay: 160.ms, duration: 500.ms)
            .slideY(begin: 0.04, end: 0, duration: 500.ms, delay: 160.ms,
                curve: Curves.easeOut),

          const SizedBox(height: Sp.md),

          // ── Archetype match ─────────────────────────────────────────────
          ArchetypeCard(match: match)
            .animate().fadeIn(delay: 320.ms, duration: 500.ms)
            .slideY(begin: 0.04, end: 0, duration: 500.ms, delay: 320.ms,
                curve: Curves.easeOut),

          const SizedBox(height: Sp.md),

          // ── Consultation CTA — sends into face-aware chat ───────────────
          _ConsultCard(
            onTap: () => context.push(
              '/chat',
              extra: {'geometry': widget.geometry},
            ),
          ).animate().fadeIn(delay: 460.ms, duration: 500.ms),

          const SizedBox(height: Sp.xl),

          // Before/after split
          Text('THE MAXIMIZED TWIN', style: AppTypography.label.copyWith(
            color: AppColors.textTertiary, letterSpacing: 2.5)),
          const SizedBox(height: Sp.sm),
          _BeforeAfter(
            before: widget.imageBytes,
            afterUrl: a.maximizedImageUrl,
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

          const SizedBox(height: Sp.xl),

          // Bone reading — the human translation of measured geometry
          if (a.report.boneReading.isNotEmpty) ...[
            _Block(
              label: 'YOUR BONE STRUCTURE',
              color: AppColors.measure,
              body: a.report.boneReading,
            ).animate().fadeIn(delay: 760.ms),
            const SizedBox(height: Sp.md),
          ],

          // Strongest trait
          _Block(
            label: 'ALREADY WORKING',
            color: AppColors.signalGreen,
            body: a.report.strongest,
          ).animate().fadeIn(delay: 860.ms),

          const SizedBox(height: Sp.md),

          // The pull-down
          _Block(
            label: 'WHAT\'S HOLDING IT BACK',
            color: AppColors.signalRed,
            body: a.report.pulldown,
          ).animate().fadeIn(delay: 960.ms),

          const SizedBox(height: Sp.xl),

          // Fixes
          Text('FIXES — ORDERED BY LEVERAGE', style: AppTypography.label.copyWith(
            color: AppColors.accent, letterSpacing: 2.0))
            .animate().fadeIn(delay: 1080.ms),
          const SizedBox(height: Sp.sm),
          ...a.report.fixes.asMap().entries.map((e) =>
            _FixCard(index: e.key + 1, fix: e.value)
              .animate().fadeIn(delay: Duration(milliseconds: 1140 + e.key * 100))),

          const SizedBox(height: Sp.xl),

          // Verdict
          _Verdict(text: a.report.verdict)
            .animate().fadeIn(delay: 1500.ms, duration: 500.ms)
            .slideY(begin: 0.05, end: 0,
                delay: 1500.ms, duration: 500.ms, curve: Curves.easeOut),

          const SizedBox(height: Sp.xl),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Rd.lg)),
                    ),
                    onPressed: () => context.go('/home'),
                    child: const Text('Done'),
                  ),
                ),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.base,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Rd.lg)),
                    ),
                    onPressed: () => context.push(
                      '/chat',
                      extra: {'geometry': widget.geometry},
                    ),
                    child: const Text('Consult',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
        ],
      ),
    );
  }
}

// ── Consultation CTA card ────────────────────────────────────────────────────
class _ConsultCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ConsultCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.xl),
        child: Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.10),
                AppColors.gold.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(Rd.xl),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6), width: 0.8),
                ),
                child: const Icon(Icons.auto_awesome,
                  size: 18, color: AppColors.gold),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONSULT THE AI',
                      style: AppTypography.label.copyWith(
                        color: AppColors.gold, letterSpacing: 2.6, fontSize: 9)),
                    const SizedBox(height: 3),
                    Text('Ask about haircut, beard, skin, surgery — answered '
                         'against your measured bones.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Before / after ────────────────────────────────────────────────────────────
class _BeforeAfter extends StatelessWidget {
  final Uint8List before;
  final String afterUrl;

  const _BeforeAfter({required this.before, required this.afterUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SideLabel('NOW', AppColors.textTertiary)),
            const SizedBox(width: 8),
            Expanded(child: _SideLabel('MAXIMIZED', AppColors.accent)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ImageTile.memory(before)),
            const SizedBox(width: 8),
            Expanded(child: _ImageTile.network(afterUrl)),
          ],
        ),
      ],
    );
  }
}

class _SideLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SideLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(text,
    style: AppTypography.label.copyWith(color: color, letterSpacing: 2.5, fontSize: 10));
}

class _ImageTile extends StatelessWidget {
  final Uint8List? bytes;
  final String?    url;

  const _ImageTile.memory(Uint8List this.bytes)  : url = null;
  const _ImageTile.network(String this.url)      : bytes = null;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rd.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(Rd.lg),
            color: AppColors.surface1,
          ),
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : (url != null && url!.isNotEmpty
                    ? Image.network(url!, fit: BoxFit.cover,
                        loadingBuilder: (c, child, p) =>
                            p == null ? child :
                            const Center(child: CircularProgressIndicator(
                              color: AppColors.accent, strokeWidth: 2)),
                        errorBuilder: (c, e, s) => Center(
                          child: Text('Image unavailable',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11))))
                    : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

// ── Block card ────────────────────────────────────────────────────────────────
class _Block extends StatelessWidget {
  final String label;
  final Color color;
  final String body;

  const _Block({required this.label, required this.color, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2, height: 36,
            margin: const EdgeInsets.only(top: 2, right: Sp.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.label.copyWith(
                  color: color, letterSpacing: 1.8, fontSize: 9)),
                const SizedBox(height: 5),
                Text(body, style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fix card ──────────────────────────────────────────────────────────────────
class _FixCard extends StatelessWidget {
  final int index;
  final Fix fix;
  const _FixCard({required this.index, required this.fix});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.md),
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(Rd.lg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$index',
                style: AppTypography.h1.copyWith(
                  color: AppColors.accent, fontSize: 28, letterSpacing: -1)),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(fix.title.toUpperCase(),
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(fix.reason,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary, height: 1.55)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          const Divider(height: 1),
          const SizedBox(height: Sp.sm),
          Text('DO THIS', style: AppTypography.label.copyWith(
            color: AppColors.measure, fontSize: 9, letterSpacing: 1.8)),
          const SizedBox(height: 4),
          Text(fix.action, style: AppTypography.body.copyWith(
            color: AppColors.textPrimary, fontSize: 14, height: 1.55)),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              _Chip(label: fix.timeline, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              _Chip(label: 'RESCAN DAY ${fix.rescanDay}', color: AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label.toUpperCase(),
      style: AppTypography.label.copyWith(
        color: color, fontSize: 9, letterSpacing: 1.4)),
  );
}

// ── Verdict ───────────────────────────────────────────────────────────────────
class _Verdict extends StatelessWidget {
  final String text;
  const _Verdict({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.accentBorder),
        boxShadow: [BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.06),
          blurRadius: 24,
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VERDICT', style: AppTypography.label.copyWith(
            color: AppColors.accent, letterSpacing: 2.5)),
          const SizedBox(height: Sp.md),
          Text(text, style: AppTypography.body.copyWith(
            height: 1.75, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
