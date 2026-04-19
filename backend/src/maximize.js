import Replicate from 'replicate';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Generate the Maximized Twin — the same person at their best.
 *
 * Critical tuning notes (learned the hard way):
 * 1. Flux Kontext Max tends to AGE the subject by default. Must explicitly
 *    preserve apparent age and rule out aging artefacts.
 * 2. Identity drift occurs when the prompt is too open. Must anchor with
 *    specific geometry values and the "same person" phrase repeated.
 * 3. If the subject has a beard, Flux cannot see the underlying jaw — so
 *    the result may look "wrong" when we try to render them leaner. Add
 *    a pose-preserve constraint so the beard itself remains.
 * 4. The improvements list is capped at 2–3 items. More = identity drift.
 */
export async function maximize({ imageBase64, brief, geometry }) {
  const improve  = (brief?.improve  ?? []).slice(0, 3);
  const preserve = brief?.preserve ?? [];

  const geometryAnchors = buildAnchors(geometry);
  const prompt = buildPrompt({ geometryAnchors, improve, preserve });

  const input = {
    prompt,
    input_image: `data:image/jpeg;base64,${imageBase64}`,
    aspect_ratio: 'match_input_image',
    output_format: 'jpg',
    safety_tolerance: 2,
    prompt_upsampling: false, // keep prompt exact
  };

  const output = await replicate.run(MODEL, { input });
  const url = typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));

  return { url, prompt };
}

function buildAnchors(geometry) {
  if (!geometry) return [];
  return [
    geometry.canthalTilt     != null ? `canthal tilt ${geometry.canthalTilt.toFixed(1)}°`     : null,
    geometry.fwhr            != null ? `FWHR ${geometry.fwhr.toFixed(2)}`                      : null,
    geometry.eyeSpacingRatio != null ? `eye spacing ${geometry.eyeSpacingRatio.toFixed(2)}`    : null,
    geometry.jawAngle        != null ? `jaw angle ${geometry.jawAngle.toFixed(0)}°`             : null,
    geometry.faceLengthRatio != null ? `face length ratio ${geometry.faceLengthRatio.toFixed(2)}`: null,
    geometry.headShape       ? `head shape ${geometry.headShape}` : null,
    geometry.lipFullness     != null ? `lip fullness ${geometry.lipFullness.toFixed(2)}`        : null,
    geometry.facialThirdTop  != null
      ? `thirds ${geometry.facialThirdTop.toFixed(0)}/${geometry.facialThirdMid.toFixed(0)}/${geometry.facialThirdLow.toFixed(0)}`
      : null,
  ].filter(Boolean);
}

function buildPrompt({ geometryAnchors, improve, preserve }) {
  const preserveList = [
    'exact same person',
    'same apparent age — do NOT age the subject older or younger',
    'exact bone structure and proportions',
    'exact eye shape, eye colour, eye size, distance between eyes',
    'exact nose shape and width and length',
    'exact lip shape and fullness',
    'exact face width and length ratio',
    'exact ethnicity and skin tone',
    'exact jawline geometry',
    'exact brow position and shape',
    'exact hairline and hair colour (unless explicitly changed)',
    'exact facial hair presence (beard/stubble stays unless explicitly changed)',
    'same pose, same angle, same expression',
    ...preserve,
  ];

  const improveList = (improve && improve.length > 0) ? improve : [
    'improved skin clarity — even tone, reduced blemishes, KEEP natural skin texture',
    'subtle under-eye brightness — reduce dark circles without smoothing',
    'subtle natural contrast lift from better lighting — do not sharpen features',
  ];

  const geometryBlock = geometryAnchors.length > 0
    ? `\nMEASURED IDENTITY ANCHORS — these values MUST be preserved exactly:\n${geometryAnchors.map(g => `- ${g}`).join('\n')}\n`
    : '';

  return `Edit this photo to show the EXACT SAME PERSON at their best — a subtle, believable improvement. NOT a transformation. NOT a beautification. NOT a filter. A realistic version of the same person on a better day.
${geometryBlock}
CRITICAL IDENTITY PRESERVATION — do NOT change:
${preserveList.map(p => `- ${p}`).join('\n')}

APPLY THESE IMPROVEMENTS ONLY — subtle, never heavy-handed:
${improveList.map(i => `- ${i}`).join('\n')}

ABSOLUTE RULES — these are FAIL conditions, not suggestions:
- DO NOT make the subject look OLDER. Preserve apparent age exactly.
- DO NOT make the subject look UGLIER or more tired. Preserve freshness.
- DO NOT apply a "beauty filter" smoothing — skin texture must remain natural.
- DO NOT enlarge eyes, narrow nose, sharpen jaw structurally. Only lighting/contrast may enhance existing structure.
- DO NOT change ethnicity, bone structure, or any identifying feature.
- DO NOT stylise, paint, HDR, oversaturate, or add any artistic effect.
- DO NOT add symmetrical perfection — natural asymmetries must remain.
- DO NOT change expression, pose, or angle.
- DO NOT change the background beyond a clean neutralisation.
- DO NOT change what is covered by facial hair — if there is a beard, it stays.

STYLE: photorealistic portrait photography, natural daylight, same pose, same angle, same expression, same framing. Shot on an 85mm lens.

SUCCESS TEST: a friend who knows this person should say "they look great today" — not "did they get work done" or "who is that?". If the identity drifts, the render has failed.`;
}
