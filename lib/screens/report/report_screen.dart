import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/face_geometry.dart';
import '../../models/mirror_analysis.dart';
import '../../models/scan_record.dart';
import '../../services/archetype_service.dart';
import '../../services/face_asset_service.dart';
import '../../services/local_store_service.dart';
import '../../services/mirror_api_service.dart';
import '../../services/scoring_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/chat_service.dart';
import '../../services/share_service.dart';
import '../../widgets/common/before_after_card.dart';
import '../../widgets/common/fullscreen_image.dart';
import '../../widgets/common/quick_tryon_chips.dart';
import '../../widgets/report/archetype_card.dart';
import '../../widgets/report/measurement_grid.dart';
import '../../widgets/report/score_card.dart';
import '../../widgets/report/verdict_card.dart';

class ReportScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final FaceGeometry geometry;
  final List<Uint8List> extraImages;

  const ReportScreen({
    super.key,
    required this.imageBytes,
    required this.geometry,
    this.extraImages = const [],
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
        imageBytes:  widget.imageBytes,
        geometry:    widget.geometry,
        extraImages: widget.extraImages,
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
    final id = 'scan-${DateTime.now().millisecondsSinceEpoch}';

    // Save the oriented JPEG to app docs so the advisor + tryon + gallery
    // can load it later without hitting the camera again.
    String? savedPath;
    try {
      savedPath = await FaceAssetService.saveScanImage(
        scanId: id, bytes: widget.imageBytes);
    } catch (_) {}

    final record = ScanRecord(
      id:                 id,
      takenAt:            DateTime.now(),
      geometry:           widget.geometry,
      score:              score.value,
      tierLabel:          score.tierLabel,
      archetypeName:      match.archetype.name,
      archetypeMatchPct:  (match.match * 100).round(),
      capturedImagePath:  savedPath,
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
          // Header with Share action
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR ANALYSIS', style: AppTypography.label.copyWith(
                      color: AppColors.textTertiary, letterSpacing: 2.5))
                      .animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: Sp.xs),
                    Text('Down to the millimetre.',
                      style: AppTypography.h1.copyWith(fontSize: 28))
                      .animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  ],
                ),
              ),
              _ShareButton(
                onTap: () => ShareService.shareComposed(
                  context:     context,
                  beforeBytes: widget.imageBytes,
                  afterUrl:    a.maximizedImageUrl,
                  score:       score.value,
                  tier:        score.tierLabel,
                  archetype:   match.archetype.name,
                  verdict:     a.report.oneLineVerdict,
                  text: 'My face, measured — ${score.value}/100, '
                        '${score.tierLabel}, ${match.archetype.name}. mirrorly.app',
                ),
              ),
            ],
          ),

          const SizedBox(height: Sp.xl),

          // ── HERO VERDICT · screenshot-gold ──────────────────────────────
          if (a.report.oneLineVerdict.isNotEmpty) ...[
            VerdictCard(
              verdict:   a.report.oneLineVerdict,
              score:     score.value,
              tier:      score.tierLabel,
              archetype: match.archetype.name),
            const SizedBox(height: Sp.md),
          ],

          // ── Score + axes ────────────────────────────────────────────────
          ScoreCard(score: score)
            .animate().fadeIn(delay: 160.ms, duration: 500.ms),

          const SizedBox(height: Sp.md),

          // ── Maximized Twin · NOW vs MAXIMIZED · tappable, caption-worthy ─
          BeforeAfterCard(
            beforeBytes: widget.imageBytes,
            afterUrl:    a.maximizedImageUrl,
            caption:     a.report.oneLineVerdict.isNotEmpty
                ? null
                : 'You, with skin, light, and grooming pushed to their best.',
          ).animate().fadeIn(delay: 240.ms, duration: 600.ms),

          const SizedBox(height: Sp.md),

          // ── Quick-action chips — fires tryon on tap ─────────────────────
          Text('TRY IT ON YOUR FACE',
            style: AppTypography.label.copyWith(
              color: AppColors.gold, letterSpacing: 2.5, fontSize: 9)),
          const SizedBox(height: Sp.sm),
          QuickTryonChips(
            geometry: widget.geometry,
            onTap: (style, cat) => context.push(
              '/chat',
              extra: {
                'geometry':  widget.geometry,
                'imagePath': null,
                'autoSend':  style,
              },
            ),
          ).animate().fadeIn(delay: 360.ms, duration: 500.ms),

          const SizedBox(height: Sp.md),

          // ── Measurement grid — the precision proof ──────────────────────
          MeasurementGrid(g: widget.geometry)
            .animate().fadeIn(delay: 420.ms, duration: 500.ms),

          const SizedBox(height: Sp.md),

          // ── Archetype match ─────────────────────────────────────────────
          ArchetypeCard(match: match)
            .animate().fadeIn(delay: 520.ms, duration: 500.ms),

          const SizedBox(height: Sp.md),

          // ── Consultation CTA — sends into face-aware chat ───────────────
          _ConsultCard(
            onTap: () => context.push(
              '/chat',
              extra: {'geometry': widget.geometry, 'imagePath': null},
            ),
          ).animate().fadeIn(delay: 620.ms, duration: 500.ms),

          const SizedBox(height: Sp.xl),

          // Bone reading — the human translation of measured geometry
          if (a.report.boneReading.isNotEmpty) ...[
            _Block(
              label: 'THE READ',
              color: AppColors.measure,
              body: a.report.boneReading,
            ).animate().fadeIn(delay: 780.ms),
            const SizedBox(height: Sp.md),
          ],

          // Strongest trait
          _Block(
            label: 'WHAT\'S ALREADY WORKING',
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
            _FixCard(
              index: e.key + 1, fix: e.value,
              capturedBytes: widget.imageBytes,
              geometry:      widget.geometry,
            ).animate().fadeIn(delay: Duration(milliseconds: 1140 + e.key * 100))),

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

// ── Share button (top-right of report header) ───────────────────────────────
class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ios_share_rounded,
                size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Text('SHARE',
                style: AppTypography.label.copyWith(
                  color: AppColors.gold, letterSpacing: 2.0, fontSize: 10,
                  fontWeight: FontWeight.w800)),
            ],
          ),
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
class _FixCard extends StatefulWidget {
  final int index;
  final Fix fix;
  final Uint8List? capturedBytes;
  final FaceGeometry geometry;
  const _FixCard({
    required this.index, required this.fix,
    required this.capturedBytes, required this.geometry,
  });
  @override
  State<_FixCard> createState() => _FixCardState();
}

class _FixCardState extends State<_FixCard> {
  String? _renderUrl;
  bool    _rendering = false;
  String? _renderError;

  Future<void> _seeIt() async {
    if (_rendering) return;
    setState(() { _rendering = true; _renderError = null; });

    try {
      // Build a tryon style request from the fix action + title.
      final style = '${widget.fix.title}: ${widget.fix.action}';
      final cat   = _guessCategory(widget.fix.title, widget.fix.action);
      // Save bytes to disk on-the-fly so TryOnService can load them.
      final bytes = widget.capturedBytes;
      String? url;
      if (bytes != null) {
        // Inline call — bypass the service's file-path loading by posting
        // bytes directly. Simpler: reuse the service by saving a temp file.
        final tempId = 'fix-${DateTime.now().millisecondsSinceEpoch}';
        final path = await FaceAssetService.saveScanImage(
          scanId: tempId, bytes: bytes);
        url = await TryOnService.render(
          imagePath:    path,
          styleRequest: style,
          category:     cat,
          geometry:     widget.geometry,
        );
      }
      if (!mounted) return;
      setState(() {
        _renderUrl = url;
        _rendering = false;
        _renderError = url == null ? 'Couldn\'t render — try again' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rendering = false;
        _renderError = 'Error rendering';
      });
    }
  }

  String _guessCategory(String title, String action) {
    final t = '$title $action'.toLowerCase();
    if (RegExp(r'\b(hair|fade|crop|cut|fringe|undercut|buzz|trim|taper)\b').hasMatch(t)) return 'haircut';
    if (RegExp(r'\b(beard|stubble|facial hair|goatee|mustache)\b').hasMatch(t))          return 'beard';
    if (RegExp(r'\b(glasses|frame|eyewear|specs)\b').hasMatch(t))                         return 'glasses';
    if (RegExp(r'\b(lean|cut|body|weight|fat|recomp)\b').hasMatch(t))                     return 'weight';
    if (RegExp(r'\b(color|dye|tint)\b').hasMatch(t))                                      return 'hair_color';
    return 'haircut';
  }

  @override
  Widget build(BuildContext context) {
    final fix = widget.fix;
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
              Text('${widget.index}',
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
          const SizedBox(height: Sp.md),

          // "See It" — generates a Flux Kontext render of the user with this change
          if (_renderUrl != null)
            GestureDetector(
              onTap: () => FullscreenImage.open(context,
                url: _renderUrl, caption: fix.title),
              child: Container(
                width: double.infinity,
                height: 160,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Rd.md),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                ),
                child: Image.network(_renderUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text('Render unavailable',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted))),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity, height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
                  foregroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Rd.md)),
                ),
                onPressed: _rendering ? null : _seeIt,
                child: _rendering
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8, color: AppColors.gold))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome,
                          size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text('SEE IT ON YOUR FACE',
                          style: AppTypography.label.copyWith(
                            color: AppColors.gold, letterSpacing: 2.0,
                            fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
              ),
            ),
          if (_renderError != null) ...[
            const SizedBox(height: 6),
            Text(_renderError!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.signalAmber, fontSize: 11)),
          ],
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
