import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/face_geometry.dart';
import '../models/mirror_analysis.dart';

class MirrorApiService {
  static Map<String, dynamic> _geometryToJson(FaceGeometry g) => {
    // Original 9 — stable contract with existing backend
    'canthalTilt':          g.canthalTilt,
    'symmetryScore':        g.symmetryScore,
    'facialThirdTop':       g.facialThirdTop,
    'facialThirdMid':       g.facialThirdMid,
    'facialThirdLow':       g.facialThirdLow,
    'fwhr':                 g.fwhr,
    'eyeSpacingRatio':      g.eyeSpacingRatio,
    'jawAngle':             g.jawAngle,
    'chinProjection':       g.chinProjection,
    // Extended 7 — unlocks "head shape", "lip fullness", etc. in advice
    'faceLengthRatio':      g.faceLengthRatio,
    'noseLengthRatio':      g.noseLengthRatio,
    'lipFullness':          g.lipFullness,
    'brow2EyeGap':          g.brow2EyeGap,
    'philtrumRatio':        g.philtrumRatio,
    'interpupillaryRatio':  g.interpupillaryRatio,
    'headShape':            g.headShape,
  };

  /// Serializable form, callable from chat_service.dart.
  static Map<String, dynamic> geometryToJson(FaceGeometry g) => _geometryToJson(g);

  /// Run full scan: analyse + maximize in one round-trip.
  /// `extraImages` are additional angles (left 3/4, right 3/4). The backend
  /// can use these for richer vision analysis via GPT-4o; Flux still uses
  /// only the front image (imageBytes) for identity-locked rendering.
  static Future<MirrorAnalysis> scan({
    required Uint8List imageBytes,
    required FaceGeometry geometry,
    List<Uint8List> extraImages = const [],
  }) async {
    final payload = <String, dynamic>{
      'imageBase64': base64Encode(imageBytes),
      'geometry':    _geometryToJson(geometry),
    };
    if (extraImages.isNotEmpty) {
      payload['extraImagesBase64'] =
          extraImages.map((b) => base64Encode(b)).toList();
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.backendBaseUrl}/scan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Backend ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return MirrorAnalysis.fromJson(decoded);
  }
}
