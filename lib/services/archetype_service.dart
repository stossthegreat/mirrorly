import 'dart:math' as math;
import '../models/face_geometry.dart';

/// Reference geometry profile for an archetype. Values are normalized
/// targets derived from composite studies of celebrity/archetypal faces
/// — close enough to ring true, aspirational enough to drive sharing.
class Archetype {
  final String name;
  final String tagline;
  final String story;
  final double canthalTilt;
  final double symmetryScore;
  final double thirdsBalance; // composite: deviation from 33/33/33 (inverted)
  final double fwhr;
  final double eyeSpacingRatio;
  final double jawAngle;
  final double chinProjection;

  const Archetype({
    required this.name,
    required this.tagline,
    required this.story,
    required this.canthalTilt,
    required this.symmetryScore,
    required this.thirdsBalance,
    required this.fwhr,
    required this.eyeSpacingRatio,
    required this.jawAngle,
    required this.chinProjection,
  });
}

class ArchetypeMatch {
  final Archetype archetype;
  final double match; // 0..1 → display as %
  const ArchetypeMatch(this.archetype, this.match);
}

class ArchetypeService {
  /// Curated archetype library. Kept small and distinct so the top-1 feels
  /// decisive. Extend over time; never let it feel like a dropdown.
  static const library = <Archetype>[
    Archetype(
      name: 'Nordic Apex',
      tagline: 'Glacial, angular, sovereign',
      story:
        'Sharp zygomatic shelf, forward-set eyes, long ramus. Reads cold, '
        'camera-ready, executive. Think Skarsgård, Alexander.',
      canthalTilt: 4.0,
      symmetryScore: 88,
      thirdsBalance: 0.90,
      fwhr: 1.95,
      eyeSpacingRatio: 0.47,
      jawAngle: 118,
      chinProjection: 3.0,
    ),
    Archetype(
      name: 'Mediterranean Hunter',
      tagline: 'Warm, dense, carved',
      story:
        'Deep-set hunter eyes, compact midface, strong mandible. The '
        'classical leading-man template — Cavill, Dornan, di Caprio.',
      canthalTilt: 3.5,
      symmetryScore: 85,
      thirdsBalance: 0.88,
      fwhr: 1.88,
      eyeSpacingRatio: 0.45,
      jawAngle: 120,
      chinProjection: 3.5,
    ),
    Archetype(
      name: 'Slavic Monolith',
      tagline: 'Broad, stoic, tectonic',
      story:
        'Wide malar bone, high FWHR, square mandible. Reads powerful, '
        'unbothered. Adonis-coded — think Plemyannikov, Aksenov.',
      canthalTilt: 2.0,
      symmetryScore: 82,
      thirdsBalance: 0.85,
      fwhr: 2.10,
      eyeSpacingRatio: 0.48,
      jawAngle: 116,
      chinProjection: 2.5,
    ),
    Archetype(
      name: 'East-Asian Precision',
      tagline: 'Clean, linear, surgical',
      story:
        'Minimal vertical excess, precise thirds, refined jaw transition. '
        'The idol blueprint — Jung, Wang, Lee.',
      canthalTilt: 4.5,
      symmetryScore: 90,
      thirdsBalance: 0.93,
      fwhr: 1.75,
      eyeSpacingRatio: 0.46,
      jawAngle: 122,
      chinProjection: 2.0,
    ),
    Archetype(
      name: 'Classical Greek',
      tagline: 'Divine proportion, textbook',
      story:
        'Golden-ratio thirds, balanced FWHR, mild positive tilt. The '
        'sculptor\'s template. Reads timeless, not trendy.',
      canthalTilt: 3.0,
      symmetryScore: 92,
      thirdsBalance: 0.95,
      fwhr: 1.85,
      eyeSpacingRatio: 0.46,
      jawAngle: 120,
      chinProjection: 3.0,
    ),
    Archetype(
      name: 'Executive',
      tagline: 'Mature, dominant, commanding',
      story:
        'Forward chin, mature fat-pad structure, wider bizygomatic. Reads '
        'authority. Older-Clooney / Hamm territory.',
      canthalTilt: 1.5,
      symmetryScore: 80,
      thirdsBalance: 0.82,
      fwhr: 2.05,
      eyeSpacingRatio: 0.47,
      jawAngle: 119,
      chinProjection: 4.0,
    ),
    Archetype(
      name: 'Ethereal',
      tagline: 'Long, soft, androgynous',
      story:
        'Elongated mid-face, softer jaw ramus, slightly wider eye spacing. '
        'Reads model, not movie-star. Elfin.',
      canthalTilt: 3.5,
      symmetryScore: 86,
      thirdsBalance: 0.78,
      fwhr: 1.65,
      eyeSpacingRatio: 0.50,
      jawAngle: 128,
      chinProjection: 1.5,
    ),
    Archetype(
      name: 'Street Alpha',
      tagline: 'Wide, aggressive, magnetic',
      story:
        'High FWHR, pronounced gonial angle, forward brow-ridge. Reads '
        'physical, disarming. Athlete/boxer archetype.',
      canthalTilt: 2.5,
      symmetryScore: 81,
      thirdsBalance: 0.84,
      fwhr: 2.15,
      eyeSpacingRatio: 0.45,
      jawAngle: 114,
      chinProjection: 3.5,
    ),
  ];

  static ArchetypeMatch bestMatch(FaceGeometry g) {
    final matches = library.map((a) => ArchetypeMatch(a, _similarity(g, a))).toList();
    matches.sort((a, b) => b.match.compareTo(a.match));
    return matches.first;
  }

  static List<ArchetypeMatch> rankAll(FaceGeometry g) {
    final matches = library.map((a) => ArchetypeMatch(a, _similarity(g, a))).toList();
    matches.sort((a, b) => b.match.compareTo(a.match));
    return matches;
  }

  /// Weighted inverse-distance similarity, mapped to 0..1.
  /// Each axis is first normalized so its natural range contributes ~equally.
  static double _similarity(FaceGeometry g, Archetype a) {
    final userThirdsBalance = _thirdsBalanceOf(g);
    final components = <(double /*user*/, double /*target*/, double /*scale*/, double /*w*/)>[
      (g.canthalTilt,      a.canthalTilt,      6.0,   1.3),
      (g.symmetryScore,    a.symmetryScore,    25.0,  1.0),
      (userThirdsBalance,  a.thirdsBalance,    0.30,  1.1),
      (g.fwhr,             a.fwhr,             0.50,  1.4),
      (g.eyeSpacingRatio,  a.eyeSpacingRatio,  0.10,  0.8),
      (g.jawAngle,         a.jawAngle,         18.0,  1.3),
      (g.chinProjection,   a.chinProjection,   5.0,   1.0),
    ];

    double sumWeighted = 0;
    double sumWeights  = 0;
    for (final (u, t, scale, w) in components) {
      final dev = ((u - t) / scale).abs();
      final axisSim = math.max(0.0, 1.0 - dev);
      sumWeighted += axisSim * w;
      sumWeights  += w;
    }
    final raw = sumWeighted / sumWeights;
    // Expand the middle of the distribution so archetypes feel distinct
    // (75 % never reads as "meh" — push toward decisive match).
    return math.pow(raw, 0.75).toDouble().clamp(0.0, 1.0);
  }

  static double _thirdsBalanceOf(FaceGeometry g) {
    const ideal = 33.33;
    final dev = math.sqrt(
      (math.pow(g.facialThirdTop - ideal, 2) +
       math.pow(g.facialThirdMid - ideal, 2) +
       math.pow(g.facialThirdLow - ideal, 2)) / 3,
    );
    return (1.0 - dev / 10).clamp(0.0, 1.0);
  }
}
