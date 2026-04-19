import 'package:flutter/material.dart';
import '../../services/face_mesh_service.dart';

enum ScanPhase { searching, scanning, measuring, capturing, analysing }

/// The scroll-stopping visual: 468 landmarks forming across a live face
/// with measurement callouts resolving into the HUD.
class GeometryOverlayPainter extends CustomPainter {
  final FaceMesh? mesh;
  final ScanPhase phase;
  final double progress;       // 0→1 — drives dot reveal, line draw, and measurement resolution
  final double lockProgress;   // 0→1 frame lock animation
  final int countdown;         // 3→2→1 during capture

  const GeometryOverlayPainter({
    required this.mesh,
    required this.phase,
    required this.progress,
    this.lockProgress = 0,
    this.countdown = 0,
  });

  static const _dotColor     = Color(0xFF818CF8); // indigo-400
  static const _measureColor = Color(0xFF38BDF8); // sky-400
  static const _boneColor    = Color(0xFFD4A96A); // gold — structural bone lines

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == ScanPhase.searching) {
      _drawSearchingReticle(canvas, size);
      return;
    }

    if (mesh == null || !mesh!.isValid) return;

    // Staggered dot reveal — 0–60% of progress drives this
    if (phase == ScanPhase.scanning ||
        phase == ScanPhase.measuring ||
        phase == ScanPhase.capturing ||
        phase == ScanPhase.analysing) {
      _drawMeshDots(canvas, size);
    }

    // Mesh connection lines — 40–80% of progress
    if (progress > 0.35 &&
        (phase == ScanPhase.scanning ||
         phase == ScanPhase.measuring ||
         phase == ScanPhase.capturing ||
         phase == ScanPhase.analysing)) {
      _drawMeshLines(canvas, size);
    }

    // Bone structure lines — the premium visual. Drawn during measuring/
    // capturing phases on top of the mesh to show the user we're reading
    // cranial structure, not just surface points. Gold = premium/earned.
    if (phase == ScanPhase.measuring ||
        phase == ScanPhase.capturing ||
        phase == ScanPhase.analysing) {
      _drawBoneStructure(canvas, size);
    }

    // Measurement callouts — after dots are mostly in
    if (progress > 0.55 &&
        (phase == ScanPhase.measuring ||
         phase == ScanPhase.capturing ||
         phase == ScanPhase.analysing)) {
      _drawMeasurementCallouts(canvas, size);
    }

    // Scan line sweep
    if (phase == ScanPhase.scanning) {
      _drawScanLine(canvas, size);
    }

    // Capture frame + countdown
    if (phase == ScanPhase.capturing) {
      _drawCaptureFrame(canvas, size);
      if (countdown > 0) _drawCountdown(canvas, size);
    }

    // Analysing pulse
    if (phase == ScanPhase.analysing) {
      _drawAnalysingPulse(canvas, size);
    }
  }

  // ── Searching reticle (no face yet) ────────────────────────────────────────
  void _drawSearchingReticle(Canvas canvas, Size size) {
    const arm = 28.0;
    final paint = Paint()
      ..color = _measureColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;

    final corners = [
      (Offset(size.width * 0.22, size.height * 0.18),  1.0,  1.0),
      (Offset(size.width * 0.78, size.height * 0.18), -1.0,  1.0),
      (Offset(size.width * 0.22, size.height * 0.82),  1.0, -1.0),
      (Offset(size.width * 0.78, size.height * 0.82), -1.0, -1.0),
    ];
    for (final (p, sx, sy) in corners) {
      canvas.drawLine(p, Offset(p.dx + sx * arm, p.dy), paint);
      canvas.drawLine(p, Offset(p.dx, p.dy + sy * arm), paint);
    }

    // Center crosshair
    final cx = size.width / 2;
    final cy = size.height / 2;
    final faint = Paint()
      ..color = _measureColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - 14, cy), Offset(cx + 14, cy), faint);
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx, cy + 14), faint);
  }

  // ── 468 dots, staggered reveal ─────────────────────────────────────────────
  void _drawMeshDots(Canvas canvas, Size size) {
    final points = mesh!.points;
    final total  = points.length;

    // Progress 0–0.6 maps to dot reveal (0–total visible)
    final revealPct = (progress / 0.6).clamp(0.0, 1.0);
    final visible   = (total * revealPct).floor();

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < visible; i++) {
      final p = points[i];
      final x = p.dx * size.width;
      final y = p.dy * size.height;

      // Fade in each dot over a short window based on its index
      final localProgress =
          ((revealPct * total - i).clamp(0.0, 3.0)) / 3.0;
      final alpha = (0.25 + 0.6 * localProgress).clamp(0.0, 0.85);

      dotPaint.color = _dotColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
    }
  }

  // ── Mesh connection lines between nearby points ────────────────────────────
  void _drawMeshLines(Canvas canvas, Size size) {
    final points = mesh!.points;
    final linePct = ((progress - 0.35) / 0.3).clamp(0.0, 1.0);

    final linePaint = Paint()
      ..color = _dotColor.withValues(alpha: 0.18 * linePct)
      ..strokeWidth = 0.6;

    // Draw only a subset of structural edges — the key face mesh skeleton
    // to avoid a spaghetti mess. We connect each point to ~2 nearest neighbors
    // using pre-selected MediaPipe face oval + eye contours.
    const edges = _faceMeshEdges;
    for (final (a, b) in edges) {
      if (a >= points.length || b >= points.length) continue;
      final pa = points[a];
      final pb = points[b];
      canvas.drawLine(
        Offset(pa.dx * size.width, pa.dy * size.height),
        Offset(pb.dx * size.width, pb.dy * size.height),
        linePaint,
      );
    }
  }

  // ── Bone structure lines (mandible, zygomatic, orbital, frontal, chin) ────
  // Gold, surgical. Each segment fades in in sequence so the user perceives
  // the *reveal* of structure — not just decoration.
  void _drawBoneStructure(Canvas canvas, Size size) {
    final points = mesh!.points;
    // The bone lines rely on MediaPipe 468-index topology. On the iOS
    // contour fallback we only get unindexed outline points — skip rather
    // than draw nonsense lines.
    if (points.length < 200) return;

    // Progress 0–1 controls sequential reveal; after capturing hold at full.
    final reveal = phase == ScanPhase.measuring
        ? ((progress - 0.15) / 0.6).clamp(0.0, 1.0)
        : 1.0;
    if (reveal <= 0) return;

    Offset? px(int i) {
      if (i >= points.length) return null;
      final p = points[i];
      return Offset(p.dx * size.width, p.dy * size.height);
    }

    void drawChain(List<int> indices, double phaseStart, double phaseEnd,
        {double width = 1.3, double alpha = 0.85}) {
      final local = ((reveal - phaseStart) / (phaseEnd - phaseStart)).clamp(0.0, 1.0);
      if (local <= 0) return;
      final pts = indices.map(px).whereType<Offset>().toList();
      if (pts.length < 2) return;

      // Reveal by drawing only a fraction of segments
      final totalSegs = pts.length - 1;
      final drawSegs  = (totalSegs * local).floor();
      final partial   = (totalSegs * local) - drawSegs;

      final paint = Paint()
        ..color = _boneColor.withValues(alpha: alpha * local.clamp(0.35, 1.0))
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i <= drawSegs; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      if (drawSegs < totalSegs && partial > 0) {
        final a = pts[drawSegs];
        final b = pts[drawSegs + 1];
        path.lineTo(a.dx + (b.dx - a.dx) * partial,
                    a.dy + (b.dy - a.dy) * partial);
      }
      canvas.drawPath(path, paint);

      // Anchor pips at joint points
      final pipPaint = Paint()
        ..color = _boneColor.withValues(alpha: 0.95 * local)
        ..style = PaintingStyle.fill;
      for (var i = 0; i < drawSegs + 1 && i < pts.length; i++) {
        canvas.drawCircle(pts[i], 1.6, pipPaint);
      }
    }

    // Mandible (jaw line) — the defining bone. First to reveal.
    drawChain(const [
      234, 93, 132, 58, 172, 136, 150, 149, 176, 148, 152,
      377, 400, 378, 379, 365, 397, 288, 361, 323, 454,
    ], 0.00, 0.35, width: 1.6);

    // Zygomatic shelf (cheekbone plane) — left
    drawChain(const [234, 227, 116, 123, 117, 118, 101], 0.25, 0.55);
    // Zygomatic shelf — right
    drawChain(const [454, 447, 345, 352, 346, 347, 330], 0.25, 0.55);

    // Orbital frame — left eye socket outline
    drawChain(const [
      33, 246, 161, 160, 159, 158, 157, 173, 133, 155, 154, 153, 145, 144, 163, 7, 33,
    ], 0.40, 0.70, width: 1.0, alpha: 0.75);
    // Orbital frame — right eye socket outline
    drawChain(const [
      263, 466, 388, 387, 386, 385, 384, 398, 362, 382, 381, 380, 374, 373, 390, 249, 263,
    ], 0.40, 0.70, width: 1.0, alpha: 0.75);

    // Frontal bone sweep (brow-to-brow arc)
    drawChain(const [70, 63, 105, 66, 107, 9, 336, 296, 334, 293, 300],
        0.55, 0.80, width: 1.1);

    // Nose bridge (vertical axis)
    drawChain(const [168, 6, 197, 195, 5, 4, 1], 0.60, 0.85, width: 1.1);

    // Chin projection vector (mental tubercle)
    drawChain(const [152, 175, 199, 200, 18], 0.70, 0.92, width: 1.3);

    // Final lockup: hairline anchors drawn as discrete gold pips
    final hairPoints = const [10, 109, 67, 103, 54, 21, 162, 127, 356, 389, 251, 284, 332, 297, 338];
    if (reveal > 0.85) {
      final anchorPaint = Paint()
        ..color = _boneColor.withValues(alpha: 0.85 * ((reveal - 0.85) / 0.15))
        ..style = PaintingStyle.fill;
      for (final i in hairPoints) {
        final p = px(i);
        if (p != null) canvas.drawCircle(p, 1.8, anchorPaint);
      }
    }
  }

  // ── Measurement callouts with leader lines ─────────────────────────────────
  void _drawMeasurementCallouts(Canvas canvas, Size size) {
    final pct = ((progress - 0.55) / 0.4).clamp(0.0, 1.0);

    // Canthal tilt — point from left eye outer → outward
    final leftOuter  = mesh!.at(FaceMesh.idxLeftEyeOuter);
    final rightOuter = mesh!.at(FaceMesh.idxRightEyeOuter);
    final noseTip    = mesh!.at(FaceMesh.idxNoseTip);
    final cheekL     = mesh!.at(FaceMesh.idxCheekL);
    final cheekR     = mesh!.at(FaceMesh.idxCheekR);
    final chin       = mesh!.at(FaceMesh.idxChin);

    // Canthal tilt callout — left eye corner
    if (leftOuter != null && pct > 0.1) {
      _drawCallout(
        canvas,
        size,
        anchor: Offset(leftOuter.dx * size.width, leftOuter.dy * size.height),
        labelOffset: const Offset(-64, -30),
        label: 'CANTHAL',
        reveal: ((pct - 0.1) / 0.3).clamp(0.0, 1.0),
      );
    }

    // FWHR bracket — cheekbone to cheekbone
    if (cheekL != null && cheekR != null && pct > 0.25) {
      final cl = Offset(cheekL.dx * size.width, cheekL.dy * size.height);
      final cr = Offset(cheekR.dx * size.width, cheekR.dy * size.height);
      final bracketP = Paint()
        ..color = _measureColor.withValues(alpha: 0.55 * pct)
        ..strokeWidth = 1.0;
      final yMid = (cl.dy + cr.dy) / 2;
      canvas.drawLine(Offset(cl.dx, yMid), Offset(cr.dx, yMid), bracketP);
      canvas.drawLine(Offset(cl.dx, yMid - 6), Offset(cl.dx, yMid + 6), bracketP);
      canvas.drawLine(Offset(cr.dx, yMid - 6), Offset(cr.dx, yMid + 6), bracketP);

      if (pct > 0.45) {
        _drawLabelText(canvas, Offset((cl.dx + cr.dx) / 2, yMid + 14), 'FWHR');
      }
    }

    // Jaw angle — from chin up-and-out
    if (chin != null && pct > 0.5) {
      _drawCallout(
        canvas,
        size,
        anchor: Offset(chin.dx * size.width, chin.dy * size.height),
        labelOffset: const Offset(60, 20),
        label: 'JAW',
        reveal: ((pct - 0.5) / 0.3).clamp(0.0, 1.0),
      );
    }

    // Right canthal
    if (rightOuter != null && pct > 0.7) {
      _drawCallout(
        canvas,
        size,
        anchor: Offset(rightOuter.dx * size.width, rightOuter.dy * size.height),
        labelOffset: const Offset(64, -30),
        label: 'TILT',
        reveal: ((pct - 0.7) / 0.3).clamp(0.0, 1.0),
      );
    }

    // Nose tip anchor dot (prominent)
    if (noseTip != null) {
      final p = Offset(noseTip.dx * size.width, noseTip.dy * size.height);
      canvas.drawCircle(p, 2.5, Paint()..color = _measureColor.withValues(alpha: 0.8 * pct));
    }
  }

  void _drawCallout(
    Canvas canvas,
    Size size, {
    required Offset anchor,
    required Offset labelOffset,
    required String label,
    required double reveal,
  }) {
    if (reveal <= 0) return;
    final labelPos = Offset(anchor.dx + labelOffset.dx, anchor.dy + labelOffset.dy);
    final midPos   = Offset.lerp(anchor, labelPos, reveal)!;

    final linePaint = Paint()
      ..color = _measureColor.withValues(alpha: 0.7 * reveal)
      ..strokeWidth = 0.9;

    canvas.drawLine(anchor, midPos, linePaint);

    // Small anchor dot
    canvas.drawCircle(anchor, 2.5, Paint()..color = _measureColor.withValues(alpha: 0.9 * reveal));

    // Label
    if (reveal > 0.75) {
      _drawLabelText(canvas, labelPos, label);
    }
  }

  void _drawLabelText(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _measureColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  // ── Scan line sweep ────────────────────────────────────────────────────────
  void _drawScanLine(Canvas canvas, Size size) {
    final y = size.height * (0.12 + 0.76 * progress);
    final lineShader = LinearGradient(
      colors: [
        Colors.transparent,
        _measureColor.withValues(alpha: 0.7),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2));
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()..shader = lineShader..strokeWidth = 2,
    );
  }

  // ── Capture frame + countdown ──────────────────────────────────────────────
  void _drawCaptureFrame(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      size.width * 0.1, size.height * 0.08,
      size.width * 0.9, size.height * 0.92,
    );
    final paint = Paint()
      ..color = _measureColor.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );
  }

  void _drawCountdown(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$countdown',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 88,
          fontWeight: FontWeight.w700,
          letterSpacing: -4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    ));
  }

  // ── Analysing pulse ────────────────────────────────────────────────────────
  void _drawAnalysingPulse(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (var i = 0; i < 3; i++) {
      final r     = 36.0 + i * 24 + progress * 24;
      final alpha = (1.0 - (r - 36) / 108).clamp(0.0, 0.35);
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..color = _dotColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(GeometryOverlayPainter old) =>
      old.mesh       != mesh ||
      old.phase      != phase ||
      old.progress   != progress ||
      old.countdown  != countdown ||
      old.lockProgress != lockProgress;
}

// ── Static MediaPipe face mesh edge subset (~80 edges covering face oval,
//     eyes, eyebrows, nose, lips — the skeleton, not full 2000+ edges) ───────
const List<(int, int)> _faceMeshEdges = [
  // Face oval (partial)
  (10, 338), (338, 297), (297, 332), (332, 284), (284, 251), (251, 389),
  (389, 356), (356, 454), (454, 323), (323, 361), (361, 288), (288, 397),
  (397, 365), (365, 379), (379, 378), (378, 400), (400, 377), (377, 152),
  (152, 148), (148, 176), (176, 149), (149, 150), (150, 136), (136, 172),
  (172, 58), (58, 132), (132, 93), (93, 234), (234, 127), (127, 162),
  (162, 21), (21, 54), (54, 103), (103, 67), (67, 109), (109, 10),

  // Left eye
  (33, 7), (7, 163), (163, 144), (144, 145), (145, 153), (153, 154),
  (154, 155), (155, 133), (133, 173), (173, 157), (157, 158), (158, 159),
  (159, 160), (160, 161), (161, 246), (246, 33),

  // Right eye
  (263, 249), (249, 390), (390, 373), (373, 374), (374, 380), (380, 381),
  (381, 382), (382, 362), (362, 398), (398, 384), (384, 385), (385, 386),
  (386, 387), (387, 388), (388, 466), (466, 263),

  // Left eyebrow
  (70, 63), (63, 105), (105, 66), (66, 107),
  // Right eyebrow
  (300, 293), (293, 334), (334, 296), (296, 336),

  // Nose bridge
  (168, 6), (6, 197), (197, 195), (195, 5), (5, 4), (4, 1),

  // Outer lips
  (61, 146), (146, 91), (91, 181), (181, 84), (84, 17), (17, 314),
  (314, 405), (405, 321), (321, 375), (375, 291), (291, 409), (409, 270),
  (270, 269), (269, 267), (267, 0), (0, 37), (37, 39), (39, 40), (40, 185), (185, 61),
];
