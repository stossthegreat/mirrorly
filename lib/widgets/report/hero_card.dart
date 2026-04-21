import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_typography.dart';

/// Hero card on the report page. Editorial black & white — zero gold, zero
/// gradients, zero chrome. Mirrors the share card's design language so the
/// in-app moment and the screenshot feel like one continuous thing.
///
/// Stack (top → bottom):
///   1.  54 → 76    CURRENT · PROJECTED     (slim white serif numbers)
///   2.  [ BEFORE | AFTER ]                  (tight face crop, no border)
///   3.  "You're not unattractive.           (italic serif tagline,
///        You're unoptimized."                 centered, UNDER the image)
///   4.  Top 3% hunter eyes                  (plain text, sentence case,
///       Top 5% symmetry                      17pt Inter, white)
///       Strong jaw
///
/// The score transition still animates: current counts up first, then the
/// thin arrow + projected number reveal. That remains the dopamine moment.
class HeroCard extends StatefulWidget {
  final int currentScore;       // e.g. 54
  final int projectedScore;     // e.g. 76
  final String tagline;         // "You're not unattractive. / You're unoptimized."
  final Uint8List? beforeBytes;
  final String? afterUrl;
  // Retained for API compatibility with the report screen. No longer
  // rendered — we dropped the "3 CHANGES. SAME FACE." sub-line because
  // the before/after image plus the tagline already say it, and one less
  // line makes the whole card breathe.
  final int correctionsCount;
  final List<String> microProofs; // up to 3 short lines

  const HeroCard({
    super.key,
    required this.currentScore,
    required this.projectedScore,
    required this.tagline,
    required this.beforeBytes,
    required this.afterUrl,
    required this.correctionsCount,
    required this.microProofs,
  });

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _counter;

  @override
  void initState() {
    super.initState();
    _counter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
  }

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proofs = widget.microProofs.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.lg, 36, Sp.lg, 28),
      decoration: BoxDecoration(
        // Pure #000 — no radial glow, no gradient, no gold. Content does
        // the work, the surface gets out of the way.
        color: Colors.black,
        borderRadius: BorderRadius.circular(Rd.xxl),
        // Hairline in 8% white — structural frame, not ornament.
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1 · SCORE TRANSITION ─────────────────────────────────────
          // Slimmer than before. Current in muted white, projected in
          // pure white at slightly larger size — no colour distinction.
          _ScoreTransition(
            controller: _counter,
            currentScore: widget.currentScore,
            projectedScore: widget.projectedScore,
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 92, child: Text('CURRENT',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10, letterSpacing: 3.0,
                  fontWeight: FontWeight.w700,
                ))),
              const SizedBox(width: 56),
              SizedBox(width: 92, child: Text('PROJECTED',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10, letterSpacing: 3.0,
                  fontWeight: FontWeight.w700,
                ))),
            ],
          ).animate().fadeIn(delay: 1500.ms, duration: 400.ms),

          const SizedBox(height: 26),

          // ── 2 · IMAGE ─────────────────────────────────────────────
          // Tight 5:6 portrait. BoxFit.cover + alignment(0,-0.35) pushes
          // the eyes into the upper third and drops the chest. No border,
          // no shadow — the image is the statement.
          AspectRatio(
            aspectRatio: 5 / 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Rd.md),
              child: Row(
                children: [
                  Expanded(child: _half(
                    bytes: widget.beforeBytes, url: null,
                    label: 'NOW', align: Alignment.bottomLeft)),
                  Container(width: 1, color: Colors.white),
                  Expanded(child: _half(
                    bytes: null, url: widget.afterUrl,
                    label: 'FIXED', align: Alignment.bottomRight)),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 1700.ms, duration: 500.ms),

          const SizedBox(height: 26),

          // ── 3 · TAGLINE (UNDER the image per spec) ─────────────────
          Center(
            child: Text(widget.tagline,
              textAlign: TextAlign.center,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 22, letterSpacing: -0.3,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500, height: 1.3,
              )),
          ).animate().fadeIn(delay: 1900.ms, duration: 500.ms),

          if (proofs.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(height: 1,
              color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 18),

            // ── 4 · MICRO PROOFS ─────────────────────────────────────
            // Plain text, sentence case, bigger than before so each line
            // lands as its own moment. No bullets, no boxes, no colour.
            for (var i = 0; i < proofs.length; i++) ...[
              Text(_prettyCase(proofs[i]),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 17, letterSpacing: 0.1,
                  fontWeight: FontWeight.w500, height: 1.35,
                ),
              ).animate().fadeIn(
                delay: Duration(milliseconds: 2100 + i * 140),
                duration: 350.ms,
              ).slideX(begin: -0.03, end: 0,
                delay: Duration(milliseconds: 2100 + i * 140),
                duration: 350.ms, curve: Curves.easeOut),
              if (i != proofs.length - 1) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  Widget _half({
    required Uint8List? bytes,
    required String? url,
    required String label,
    required Alignment align,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(bytes,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35))
        else if (url != null && url.isNotEmpty)
          Image.network(url,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
            errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF0C0C0C)))
        else
          const ColoredBox(color: Color(0xFF0C0C0C)),

        // Gentle scrim so corner label never fights the skin tone behind.
        Positioned(
          left: 0, right: 0, bottom: 0, height: 64,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Align(
            alignment: align,
            child: Text(label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 9.5, letterSpacing: 2.6,
                fontWeight: FontWeight.w700,
              )),
          ),
        ),
      ],
    );
  }

  String _prettyCase(String s) {
    final lower = s.toLowerCase();
    if (lower.isEmpty) return s;
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

/// Number → arrow → number block. Both numbers white (no gold). Current
/// counts up on entry, then the thin arrow + projected number reveal with
/// a subtle opacity/scale pop. Restrained — the numbers aren't the loudest
/// thing on the card anymore; the image is.
class _ScoreTransition extends StatelessWidget {
  final AnimationController controller;
  final int currentScore;
  final int projectedScore;

  const _ScoreTransition({
    required this.controller,
    required this.currentScore,
    required this.projectedScore,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeOutExpo.transform(controller.value);
        final shownCurrent = (t * currentScore).round();
        final revealT = ((controller.value - 0.7) / 0.3).clamp(0.0, 1.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 92,
              child: Text('$shownCurrent',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 64, height: 1.0, letterSpacing: -2.0,
                  color: Colors.white.withValues(alpha: 0.62),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                )),
            ),
            const SizedBox(width: 28),
            Opacity(
              opacity: revealT,
              child: Transform.scale(
                scale: 0.8 + revealT * 0.2,
                child: Text('→',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36, height: 1,
                    fontWeight: FontWeight.w300,
                  )),
              ),
            ),
            const SizedBox(width: 28),
            SizedBox(
              width: 92,
              child: Opacity(
                opacity: revealT,
                child: Transform.scale(
                  scale: 0.9 + revealT * 0.1,
                  child: Text('$projectedScore',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 76, height: 1.0, letterSpacing: -2.2,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    )),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
