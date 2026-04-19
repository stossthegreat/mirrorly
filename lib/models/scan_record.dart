import 'face_geometry.dart';

/// Immutable record of a single scan. Persisted locally so the user's
/// history survives reinstalls-until-clear, feeds the progress charts, and
/// primes the AI advisor with their most recent measurements.
class ScanRecord {
  final String id;                 // local UUID-ish timestamp id
  final DateTime takenAt;
  final FaceGeometry geometry;
  final int score;                 // 0..100 — computed from geometry at save time
  final String tierLabel;          // "Apex", "Elite", ...
  final String archetypeName;      // "Nordic Apex", etc.
  final int archetypeMatchPct;     // 0..100
  final String? capturedImagePath; // local path — null if not persisted to disk
  final String? maximizedImageUrl; // backend-returned Flux twin

  const ScanRecord({
    required this.id,
    required this.takenAt,
    required this.geometry,
    required this.score,
    required this.tierLabel,
    required this.archetypeName,
    required this.archetypeMatchPct,
    this.capturedImagePath,
    this.maximizedImageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id':                 id,
    'takenAt':            takenAt.toIso8601String(),
    'canthalTilt':        geometry.canthalTilt,
    'symmetryScore':      geometry.symmetryScore,
    'facialThirdTop':     geometry.facialThirdTop,
    'facialThirdMid':     geometry.facialThirdMid,
    'facialThirdLow':     geometry.facialThirdLow,
    'fwhr':               geometry.fwhr,
    'eyeSpacingRatio':    geometry.eyeSpacingRatio,
    'jawAngle':           geometry.jawAngle,
    'chinProjection':     geometry.chinProjection,
    'hasReliableData':    geometry.hasReliableData,
    'score':              score,
    'tierLabel':          tierLabel,
    'archetypeName':      archetypeName,
    'archetypeMatchPct':  archetypeMatchPct,
    'capturedImagePath':  capturedImagePath,
    'maximizedImageUrl':  maximizedImageUrl,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> j) => ScanRecord(
    id:       j['id'] as String,
    takenAt:  DateTime.parse(j['takenAt'] as String),
    geometry: FaceGeometry(
      canthalTilt:      (j['canthalTilt']     as num).toDouble(),
      symmetryScore:    (j['symmetryScore']   as num).toDouble(),
      facialThirdTop:   (j['facialThirdTop']  as num).toDouble(),
      facialThirdMid:   (j['facialThirdMid']  as num).toDouble(),
      facialThirdLow:   (j['facialThirdLow']  as num).toDouble(),
      fwhr:             (j['fwhr']            as num).toDouble(),
      eyeSpacingRatio:  (j['eyeSpacingRatio'] as num).toDouble(),
      jawAngle:         (j['jawAngle']        as num).toDouble(),
      chinProjection:   (j['chinProjection']  as num).toDouble(),
      hasReliableData:  j['hasReliableData'] as bool? ?? true,
    ),
    score:              (j['score'] as num).toInt(),
    tierLabel:          j['tierLabel']          as String? ?? 'Foundation',
    archetypeName:      j['archetypeName']      as String? ?? 'Classical Greek',
    archetypeMatchPct:  (j['archetypeMatchPct'] as num?)?.toInt() ?? 0,
    capturedImagePath:  j['capturedImagePath'] as String?,
    maximizedImageUrl:  j['maximizedImageUrl'] as String?,
  );
}

/// A single AI-generated image (Flux Kontext result) attached to a user
/// prompt / context so the Gallery tab can re-scroll them.
class GenerationRecord {
  final String id;
  final DateTime createdAt;
  final String prompt;        // "fade haircut with texture on top"
  final String imageUrl;
  final String? relatedScanId;

  const GenerationRecord({
    required this.id,
    required this.createdAt,
    required this.prompt,
    required this.imageUrl,
    this.relatedScanId,
  });

  Map<String, dynamic> toJson() => {
    'id':             id,
    'createdAt':      createdAt.toIso8601String(),
    'prompt':         prompt,
    'imageUrl':       imageUrl,
    'relatedScanId':  relatedScanId,
  };

  factory GenerationRecord.fromJson(Map<String, dynamic> j) => GenerationRecord(
    id:            j['id'] as String,
    createdAt:     DateTime.parse(j['createdAt'] as String),
    prompt:        j['prompt'] as String? ?? '',
    imageUrl:      j['imageUrl'] as String,
    relatedScanId: j['relatedScanId'] as String?,
  );
}
