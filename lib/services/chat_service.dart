import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/face_geometry.dart';
import 'scoring_service.dart';
import 'archetype_service.dart';

class ChatMessage {
  final ChatRole role;
  final String content;
  const ChatMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'content': content,
  };
}

enum ChatRole { user, assistant }

class ChatService {
  /// Send the full conversation + face context to the backend.
  /// The backend is expected to synthesize a system prompt that includes
  /// the geometry / score / archetype and route to a Claude/GPT endpoint.
  ///
  /// If the backend route isn't live yet (404 / 5xx / timeout), we fall
  /// back to a deterministic local stub so the UX never reads as broken.
  static Future<String> send({
    required List<ChatMessage> history,
    required FaceGeometry geometry,
  }) async {
    final score = ScoringService.compute(geometry);
    final match = ArchetypeService.bestMatch(geometry);

    final context = {
      'geometry':  _geometryToJson(geometry),
      'score':     score.value,
      'tier':      score.tierLabel,
      'archetype': {
        'name':  match.archetype.name,
        'match': (match.match * 100).round(),
      },
    };

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': history.map((m) => m.toJson()).toList(),
          'face':     context,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final reply = decoded['reply'] as String?;
        if (reply != null && reply.isNotEmpty) return reply;
      }
    } catch (_) {
      // Fall through to local stub.
    }

    return _localFallback(history.isNotEmpty ? history.last.content : '', score, match);
  }

  static Map<String, dynamic> _geometryToJson(FaceGeometry g) => {
    'canthalTilt':     g.canthalTilt,
    'symmetryScore':   g.symmetryScore,
    'facialThirdTop':  g.facialThirdTop,
    'facialThirdMid':  g.facialThirdMid,
    'facialThirdLow':  g.facialThirdLow,
    'fwhr':            g.fwhr,
    'eyeSpacingRatio': g.eyeSpacingRatio,
    'jawAngle':        g.jawAngle,
    'chinProjection':  g.chinProjection,
  };

  /// Deterministic stub used when backend is unavailable. Still conditioned
  /// on geometry + score so it feels personal, not canned.
  static String _localFallback(String userMsg, AestheticScore s, ArchetypeMatch m) {
    final lower = userMsg.toLowerCase();
    final weak = s.weakestAxis.$1;
    final strong = s.strongestAxis.$1;

    if (lower.contains('hair') || lower.contains('cut') || lower.contains('fade')) {
      return 'For your archetype (${m.archetype.name}, '
          '${(m.match * 100).round()}% match) with a ${weak.toLowerCase()} pulldown, '
          'prioritize a cut that extends vertical line and draws focus up. '
          'Mid-fade with texture on top, length 3–4 cm, side part off the '
          'stronger cheekbone. Skip the buzz — you need volume, not exposure.';
    }
    if (lower.contains('beard') || lower.contains('stubble') || lower.contains('facial hair')) {
      final jaw = s.axes.jaw;
      if (jaw < 0.55) {
        return 'Your jaw axis is currently '
            '${(jaw * 100).round()}%. Heavy stubble (4–6 mm, trimmed sharp '
            'at the angle) will add mandibular definition before any other '
            'intervention. Take the cheek line higher than feels natural.';
      }
      return 'Your jaw is already a strength. A short, precise stubble '
          '(2–3 mm) emphasizes without softening it. Clean the neckline '
          'tight to the jaw curve — don\'t let it drop.';
    }
    if (lower.contains('skin') || lower.contains('acne') || lower.contains('routine')) {
      return 'Baseline non-negotiables: azelaic acid morning, tretinoin '
          '0.025 % three nights a week (build up), SPF 50 daily. Before '
          'any chasing-perfection add-ons, lock those in for 8 weeks. '
          'Your symmetry and thirds will read clearer once skin is uniform.';
    }
    if (lower.contains('surgery') || lower.contains('jaw') || lower.contains('chin') ||
        lower.contains('implant') || lower.contains('genio')) {
      return 'Surgical consults should target your lowest axis — right now '
          'that\'s ${weak.toLowerCase()}. Before scheduling anything, '
          'exhaust: mewing (12 weeks disciplined), body-fat to 12–14 %, '
          'dental alignment if off. Those three alone shift your metrics '
          'enough to re-run this analysis and make an informed surgical call.';
    }
    if (lower.contains('gym') || lower.contains('lose') || lower.contains('fat') ||
        lower.contains('body') || lower.contains('weight')) {
      return 'Body fat is the single highest-leverage facial intervention '
          'that isn\'t a scalpel. Below 14 % body fat, your mandibular '
          'angle and zygomatic shelf both sharpen visibly. If you\'re '
          'above 18 %, a cut takes priority over any cosmetic move.';
    }
    if (lower.contains('score') || lower.contains('rating') || lower.contains('why')) {
      return 'You scored ${s.value} (${s.tierLabel}). Strongest axis: '
          '$strong. Weakest: $weak. The archetype nearest your geometry '
          'is ${m.archetype.name} (${(m.match * 100).round()}% match). '
          'The fastest ${s.value < 80 ? 'point lift' : 'refinement'} is '
          'targeting $weak — everything else compounds off it.';
    }

    return 'Consulting offline for this one. Try: "what haircut?", '
        '"skin routine?", "should I get genioplasty?", "what\'s my '
        'archetype?" — I\'ll answer any of those conditioned on your '
        'actual measurements.';
  }
}
