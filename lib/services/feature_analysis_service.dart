import '../models/face_geometry.dart';

/// Converts raw geometry into the 7 user-facing feature slots that drive the
/// Addictive Report UX: Eyes · Jaw · Face Balance · Hair · Skin · Symmetry
/// · Lips. Each slot returns a status (strong/weak/neutral), a vanity-tuned
/// label, the specific fix, and an expected point lift.
///
/// Rules baked in — from the product brief:
/// - Status labels play into vanity ("Standout", "Dominant", "Elite")
/// - Fix is specific + actionable ("Mid-fade + volume up", not "get a haircut")
/// - Point lift is concrete ("+6") so users believe the transformation
/// - Lips almost always "Balanced" — never a main fix
class FeatureAnalysisService {
  static List<FeatureRead> analyse(FaceGeometry g) => [
    _eyes(g),
    _jaw(g),
    _thirds(g),
    _hair(g),
    _skin(g),
    _symmetry(g),
    _lips(g),
  ];

  // ── EYES ────────────────────────────────────────────────────────────────
  static FeatureRead _eyes(FaceGeometry g) {
    final tilt = g.canthalTilt;
    final browGap = g.brow2EyeGap;

    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (tilt >= 2.5 && browGap >= 0.03 && browGap <= 0.055) {
      status = FeatureStatus.strong;
      label = 'Standout';
      story = 'Canthal tilt +${tilt.toStringAsFixed(1)}° · top 15% for your archetype. '
              'Your eyes read dominant before you speak.';
      fix = 'Protect this. Get 8h sleep, kill under-eye salt, shape the brow tail.';
      pointLift = 2;
    } else if (tilt < 0) {
      status = FeatureStatus.weak;
      label = 'Weak';
      story = 'Eye tilt ${tilt.toStringAsFixed(1)}° — reads droopy. '
              'This is the fastest aesthetic pulldown on your face.';
      fix = 'Brow-up grooming + subtle upper-lid shadow + orbital hydration. '
            'Lid lift consult only if cosmetic work is on the table.';
      pointLift = 8;
    } else {
      status = FeatureStatus.neutral;
      label = 'Neutral';
      story = 'Eye tilt ${tilt.toStringAsFixed(1)}° sits in the neutral band. '
              'Not a pulldown, not yet a weapon.';
      fix = 'Brow tail shaped up-and-out. Shadow contrast under the lid line. '
            'Darken lashes. Easy 3–4 point lift in a barber visit.';
      pointLift = 4;
    }

    return FeatureRead(
      slot:   FeatureSlot.eyes,
      title:  'EYES',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: 'slightly sharper eye contrast, deepened upper lid shadow, '
                   'darkened lash line, subtle under-eye brightness — do not enlarge '
                   'the eyes or change their shape',
      tryonCategory: 'skin',
    );
  }

  // ── JAW ─────────────────────────────────────────────────────────────────
  static FeatureRead _jaw(FaceGeometry g) {
    final angle = g.jawAngle;
    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (angle < 118) {
      status = FeatureStatus.strong;
      label = 'Dominant';
      story = 'Jaw angle ${angle.toStringAsFixed(0)}° · sharp, defined. '
              'Top 10% — most men would pay a surgeon for this edge.';
      fix = 'Do not cover it. 2–3mm stubble max. Keep the chin-neck line tight '
            'so the angle stays visible from every angle.';
      pointLift = 1;
    } else if (angle > 130) {
      status = FeatureStatus.weak;
      label = 'Hidden';
      story = 'Jaw angle ${angle.toStringAsFixed(0)}° — softened by either '
              'beard interference or submental fat. The line is there. It\'s '
              'just covered.';
      fix = 'Squared beard (5–7mm), trimmed high on cheek. Body-fat to 14%. '
            'Six weeks, your jaw reads sharper without surgery.';
      pointLift = 9;
    } else {
      status = FeatureStatus.neutral;
      label = 'Defined';
      story = 'Jaw at ${angle.toStringAsFixed(0)}° — solid middle-band angle. '
              'Usable, upgradable.';
      fix = 'Short squared beard rebuilds ~3mm of virtual sharpness. Drop '
            '2–3% body fat to expose more of the existing line.';
      pointLift = 5;
    }

    return FeatureRead(
      slot:   FeatureSlot.jaw,
      title:  'JAWLINE',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: 'short squared beard 5mm trimmed high on cheek, tight neckline '
                   'under the jaw curve, subtle shadow under jawline, slight '
                   'contrast between neck and jaw — preserve bone structure exactly',
      tryonCategory: 'beard',
    );
  }

  // ── FACE BALANCE (THIRDS) ──────────────────────────────────────────────
  static FeatureRead _thirds(FaceGeometry g) {
    final dev = ((g.facialThirdTop - 33.33).abs()
                + (g.facialThirdMid - 33.33).abs()
                + (g.facialThirdLow - 33.33).abs()) / 3;
    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (dev <= 2.0) {
      status = FeatureStatus.strong;
      label = 'Balanced';
      story = '${g.facialThirdTop.toStringAsFixed(0)}/${g.facialThirdMid.toStringAsFixed(0)}/${g.facialThirdLow.toStringAsFixed(0)} — '
              'near-textbook proportions. Top 10%.';
      fix = 'Nothing to fix here. Maintain balanced grooming — don\'t visually '
            'lengthen any third with bad hair or long beard.';
      pointLift = 1;
    } else if (g.facialThirdLow > 36) {
      status = FeatureStatus.weak;
      label = 'Long lower';
      story = 'Lower third ${g.facialThirdLow.toStringAsFixed(0)}% — face reads '
              'bottom-heavy. Masculine signal if styled right, unbalanced if not.';
      fix = 'Square the beard (not pointy). Keep hair taller on top. Avoid '
            'long goatee — it amplifies the pulldown.';
      pointLift = 6;
    } else if (g.facialThirdTop > 36) {
      status = FeatureStatus.weak;
      label = 'Long forehead';
      story = 'Upper third ${g.facialThirdTop.toStringAsFixed(0)}% — forehead '
              'dominates. Vertical length fights you.';
      fix = 'Textured fringe or low side-part. Never slick-back. You\'re one '
            'haircut away from +6 points.';
      pointLift = 6;
    } else {
      status = FeatureStatus.neutral;
      label = 'Close';
      story = '${g.facialThirdTop.toStringAsFixed(0)}/${g.facialThirdMid.toStringAsFixed(0)}/${g.facialThirdLow.toStringAsFixed(0)} — '
              'slight imbalance. Grooming compensates.';
      fix = 'Haircut matched to your longest third. Hairstyle chosen by '
            'architecture, not trend.';
      pointLift = 3;
    }

    return FeatureRead(
      slot:   FeatureSlot.thirds,
      title:  'FACE BALANCE',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: 'subtle redistribution via lighting and hair volume to '
                   'visually balance the three facial thirds — no morphing',
      tryonCategory: 'haircut',
    );
  }

  // ── HAIR FRAMING ────────────────────────────────────────────────────────
  static FeatureRead _hair(FaceGeometry g) {
    // No hair-specific measurement — derive from face length ratio + upper third.
    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (g.headShape == 'long') {
      status = FeatureStatus.weak;
      label = 'Weak framing';
      story = 'Head ratio ${g.faceLengthRatio.toStringAsFixed(2)} — long. '
              'Wrong hair amplifies the vertical. Right hair collapses it.';
      fix = 'Mid-fade, 3–4cm textured top, side-parted. Never long. Never '
            'slick-back. This fix alone carries the most visible lift on your face.';
      pointLift = 7;
    } else if (g.headShape == 'broad' || g.fwhr >= 2.0) {
      status = FeatureStatus.weak;
      label = 'Weak framing';
      story = 'Broad face (FWHR ${g.fwhr.toStringAsFixed(2)}) — a short crop '
              'makes your face read wider. Height on top is your weapon.';
      fix = 'Taller textured top (5–6cm), swept upward. Mid-to-low taper. '
            'Never buzz cut.';
      pointLift = 7;
    } else {
      status = FeatureStatus.neutral;
      label = 'Solid framing';
      story = 'Your head shape carries most cuts. The hair you have isn\'t '
              'fighting your bones.';
      fix = 'Optimise the haircut for your strongest side — side-part off '
            'your stronger cheekbone, textured on top.';
      pointLift = 4;
    }

    return FeatureRead(
      slot:   FeatureSlot.hair,
      title:  'HAIR FRAMING',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: g.headShape == 'long'
          ? 'mid-fade haircut, 3-4 cm textured crop on top, side-parted, '
            'compresses vertical face length'
          : g.headShape == 'broad'
            ? 'taller textured top 5-6 cm swept upward, mid-to-low taper, '
              'adds vertical balance'
            : 'mid-fade with 4 cm textured top side-parted off stronger cheekbone',
      tryonCategory: 'haircut',
    );
  }

  // ── SKIN ────────────────────────────────────────────────────────────────
  static FeatureRead _skin(FaceGeometry g) {
    // We don't measure skin directly — default to Clean unless symmetry
    // reads low (which usually correlates with skin unevenness in photos).
    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (g.symmetryScore >= 82) {
      status = FeatureStatus.strong;
      label = 'Clean';
      story = 'Symmetry ${g.symmetryScore.toStringAsFixed(0)}/100. Your skin '
              'isn\'t breaking your silhouette — that\'s earned.';
      fix = 'Protect: SPF 50 daily, moisturiser morning + night. Don\'t over-'
            'treat skin that\'s already working.';
      pointLift = 1;
    } else if (g.symmetryScore < 70) {
      status = FeatureStatus.weak;
      label = 'Uneven';
      story = 'Symmetry reads ${g.symmetryScore.toStringAsFixed(0)}/100 — '
              'texture is breaking the light on your face and dragging '
              'the whole read.';
      fix = 'Tretinoin 0.025% 3×/week (build slow), azelaic acid 10% daily, '
            'SPF 50. Eight weeks non-negotiable. Skin alone lifts you 5+ points.';
      pointLift = 7;
    } else {
      status = FeatureStatus.neutral;
      label = 'Tighten up';
      story = 'Skin is decent — it\'s not your strongest nor your weakest axis.';
      fix = 'Simple stack: gentle cleanser AM+PM, SPF 50 daily, '
            'retinol 2×/week. Results in 4 weeks.';
      pointLift = 4;
    }

    return FeatureRead(
      slot:   FeatureSlot.skin,
      title:  'SKIN',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: 'cleaner more even skin with reduced texture, healthier '
                   'tone, keep natural pores visible — no plastic blurring',
      tryonCategory: 'skin',
    );
  }

  // ── SYMMETRY ───────────────────────────────────────────────────────────
  static FeatureRead _symmetry(FaceGeometry g) {
    final s = g.symmetryScore;
    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (s >= 88) {
      status = FeatureStatus.strong;
      label = 'Elite';
      story = 'Symmetry ${s.toStringAsFixed(0)}/100 — rare. Top 5% for your '
              'archetype. Flex this.';
      fix = 'Maintain. Sleep on your back, chew both sides. Never '
            'compromise this with asymmetric grooming.';
      pointLift = 0;
    } else if (s < 72) {
      status = FeatureStatus.weak;
      label = 'Asymmetrical';
      story = 'Left vs right reads ${s.toStringAsFixed(0)}/100 — visible imbalance. '
              '80% habitual (chewing side, sleep side, posture).';
      fix = 'Gum only on weaker cheek side 15 min/day. Back-sleeping only. '
            'Thoracic mobility. 6 weeks, metric improves.';
      pointLift = 6;
    } else {
      status = FeatureStatus.neutral;
      label = 'Balanced';
      story = 'Symmetry ${s.toStringAsFixed(0)}/100 — natural asymmetry, reads normal.';
      fix = 'Minor habits: weak-side chewing, back-sleep, posture checks.';
      pointLift = 2;
    }

    return FeatureRead(
      slot:   FeatureSlot.symmetry,
      title:  'SYMMETRY',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: 'minimal symmetry adjustment — barely visible correction, '
                   'preserve natural micro-asymmetry',
      tryonCategory: 'skin',
    );
  }

  // ── LIPS ────────────────────────────────────────────────────────────────
  static FeatureRead _lips(FaceGeometry g) {
    // Per brief: lips rarely move the needle for men. Default to Balanced,
    // keep the fix minimal. This builds trust — we're not over-prescribing.
    FeatureStatus status;
    String label, story, fix;
    int pointLift;

    if (g.lipFullness < 0.35) {
      status = FeatureStatus.neutral;
      label = 'Thin';
      story = 'Lip fullness ${g.lipFullness.toStringAsFixed(2)} — on the thin '
              'side. Not a pulldown, just a styling note.';
      fix = 'Hydration. Subtle balm. No filler — chasing plumpness reads fake '
            'for men. You\'re fine.';
      pointLift = 1;
    } else if (g.lipFullness > 0.75) {
      status = FeatureStatus.neutral;
      label = 'Dominant';
      story = 'Full lips (${g.lipFullness.toStringAsFixed(2)}) — they pull focus. '
              'Make sure the rest of your grooming keeps up.';
      fix = 'No action needed. Just don\'t hide them under heavy facial hair.';
      pointLift = 0;
    } else {
      status = FeatureStatus.strong;
      label = 'Balanced';
      story = 'Fullness ${g.lipFullness.toStringAsFixed(2)} — natural male '
              'proportion. Not a feature you need to think about.';
      fix = 'No change needed. Staying here wins.';
      pointLift = 0;
    }

    return FeatureRead(
      slot:   FeatureSlot.lips,
      title:  'LIPS',
      status: status,
      statusLabel: label,
      story:  story,
      fix:    fix,
      pointLift: pointLift,
      tryonPrompt: 'subtle lip tone balance, edge clarity — no size change, '
                   'no shape change',
      tryonCategory: 'skin',
    );
  }
}

enum FeatureSlot { eyes, jaw, thirds, hair, skin, symmetry, lips }

enum FeatureStatus {
  strong,   // green — flex
  neutral,  // amber — upgrade available
  weak,     // red — primary pulldown
}

class FeatureRead {
  final FeatureSlot slot;
  final String title;              // "EYES", "JAWLINE"
  final FeatureStatus status;
  final String statusLabel;        // "Standout", "Hidden", "Elite"
  final String story;              // 1–2 sentences, vanity-tuned
  final String fix;                // specific action
  final int pointLift;             // expected score lift, 0–10
  final String tryonPrompt;        // prompt for Flux "See It" render
  final String tryonCategory;      // haircut | beard | skin | etc.

  const FeatureRead({
    required this.slot,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.story,
    required this.fix,
    required this.pointLift,
    required this.tryonPrompt,
    required this.tryonCategory,
  });
}
