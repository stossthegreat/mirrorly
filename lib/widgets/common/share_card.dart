import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 9:16 share unit. Editorial black & white — Nike / Apple / fashion spread
/// energy, never "AI app". Pure #000 background, pure #FFF type, one image,
/// one verdict, three proof lines, one footer. Nothing else.
///
/// Stack (top → bottom):
///   Mirrorly          — 40pt Playfair wordmark, unmissable, pure white
///   3 FIXES.          — 112pt italic serif (line 1)
///   SAME FACE.        — 112pt italic serif (line 2)
///   [BEFORE | AFTER]  — tight 5:6 face crop, eyes in upper third
///   You're not unattractive.
///   You're unoptimized.                — italic serif tagline, centered
///   Top 3% hunter eyes / Top 5% symmetry / Strong jaw  — 22pt plain text
///   Measured. Not guessed.             mirrorly.app
class ShareCard extends StatelessWidget {
  final Uint8List? beforeBytes;
  final String? afterUrl;
  final int correctionsCount;     // 3 → "3 FIXES."
  final List<String> microProofs; // up to 3 short lines

  const ShareCard({
    super.key,
    required this.beforeBytes,
    required this.afterUrl,
    required this.correctionsCount,
    required this.microProofs,
  });

  @override
  Widget build(BuildContext context) {
    final proofs = microProofs.take(3).toList();

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ColoredBox(
        // Pure #000000. Not 0xFF07070A, not 0xFF0A0A0A — #000.
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 70, 56, 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Wordmark — dominant, not dainty. Pure white Playfair at
              //     40pt so the brand reads from arm's length on a feed.
              Text('Mirrorly',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 40, letterSpacing: -1.0,
                  fontWeight: FontWeight.w600, height: 1,
                )),

              const SizedBox(height: 60),

              // ── Headline — the verdict. Two italic serif lines, tight
              //     leading, pure white, no gold split. Reads as one beat.
              Text('$correctionsCount FIXES.',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 112, letterSpacing: -4.0,
                  fontWeight: FontWeight.w900, height: 0.94,
                  fontStyle: FontStyle.italic,
                )),
              Text('SAME FACE.',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 112, letterSpacing: -4.0,
                  fontWeight: FontWeight.w900, height: 0.96,
                  fontStyle: FontStyle.italic,
                )),

              const SizedBox(height: 48),

              // ── Image (the main event) ────────────────────────────
              // 5:6 tall frame + alignment(0,-0.35) crops to the face,
              // drops the chest. No border, no rounded corners, no glow
              // — clean rectilinear frame, magazine style.
              AspectRatio(
                aspectRatio: 5 / 6,
                child: Row(
                  children: [
                    Expanded(child: _half(
                      bytes: beforeBytes, url: null,
                      label: 'NOW',
                      align: Alignment.bottomLeft)),
                    Container(width: 1, color: Colors.white),
                    Expanded(child: _half(
                      bytes: null, url: afterUrl,
                      label: 'FIXED',
                      align: Alignment.bottomRight)),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Tagline — italic serif, centered, sits UNDER the image.
              Center(
                child: Text(
                  "You're not unattractive.\nYou're unoptimized.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 30, letterSpacing: -0.5,
                    fontWeight: FontWeight.w400, height: 1.28,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const Spacer(),

              // ── Proof block — three plain text lines, 22pt Inter
              //     medium, sentence-case. No boxes, no bullets, no
              //     gold. Credits on a magazine spread.
              for (final p in proofs) ...[
                Text(
                  _prettyCase(p),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22, letterSpacing: 0.2,
                    fontWeight: FontWeight.w500, height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
              ],

              const SizedBox(height: 28),

              // ── Footer — small, confident.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Measured. Not guessed.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13, letterSpacing: 0.3,
                      fontWeight: FontWeight.w400,
                    )),
                  const Spacer(),
                  Text('mirrorly.app',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13, letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Half of the before/after. Image fills the frame via cover-fit biased
  /// upward. A faint gradient scrim sits behind the corner label so the
  /// text is always legible regardless of the skin tone behind it.
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

        Positioned(
          left: 0, right: 0, bottom: 0, height: 100,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: align,
            child: Text(label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12, letterSpacing: 3.6,
                fontWeight: FontWeight.w700,
              )),
          ),
        ),
      ],
    );
  }

  /// "TOP 3% HUNTER EYES" → "Top 3% hunter eyes".
  /// Editorial share reads better in sentence case than screaming caps.
  String _prettyCase(String s) {
    final lower = s.toLowerCase();
    if (lower.isEmpty) return s;
    return lower[0].toUpperCase() + lower.substring(1);
  }
}
