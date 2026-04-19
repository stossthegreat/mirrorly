import Replicate from 'replicate';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Render a single-feature edit on the user's face (haircut / beard /
 * glasses / colour / etc.) while preserving identity at surgeon-lock
 * precision.
 *
 * Tuning notes:
 * 1. Flux Kontext drifts identity when the prompt is too open. Always
 *    repeat "same person" + geometry anchors.
 * 2. Must NOT age the subject. Common failure mode.
 * 3. If changing hair / removing beard, explicitly name what to preserve
 *    that otherwise would drift (e.g. "remove beard but preserve jaw
 *    geometry exactly, even though it's currently hidden").
 */
export async function tryOn({ imageBase64, styleRequest, category, geometry }) {
  if (!styleRequest || typeof styleRequest !== 'string') {
    throw new Error('styleRequest required');
  }

  const anchors = buildAnchors(geometry);
  const prompt = buildPrompt({ styleRequest, category, anchors });

  const input = {
    prompt,
    input_image: `data:image/jpeg;base64,${imageBase64}`,
    aspect_ratio: 'match_input_image',
    output_format: 'jpg',
    safety_tolerance: 2,
    prompt_upsampling: false,
  };

  const output = await replicate.run(MODEL, { input });
  const url = typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));

  return { url, prompt, styleRequest, category };
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

function buildPrompt({ styleRequest, category, anchors }) {
  // Category-specific guidance — tells Flux exactly what zone to edit
  // and what NOT to touch.
  const categoryGuidance = {
    haircut:     'Edit ONLY the hair on the head. Preserve hairline shape. Preserve hair colour unless explicitly changed. The new cut must look like a realistic salon cut that matches this specific person\'s face shape. Do NOT change any facial feature.',
    beard:       'Edit ONLY the facial hair on the chin/jaw/upper lip. The beard must grow from natural facial-hair zones. Density must match realistic age-appropriate growth. Do NOT alter the jawline beneath, even while it\'s obscured — preserve the underlying measured jaw geometry.',
    facial_hair: 'Edit ONLY the facial hair as specified. Preserve hairline and head hair exactly. Preserve all bone structure beneath.',
    hair_color:  'Edit ONLY the hair colour. Style, length, cut must remain pixel-identical.',
    glasses:     'Add or change only the eyewear. Do NOT alter face shape, eye shape, eye size, or any facial feature. Do NOT age the subject.',
    weight:      'Show a subtle natural change in facial fat distribution as described. Maximum 5–8% change. Preserve bone structure exactly. Do NOT sharpen features artificially.',
  };

  const guidance = categoryGuidance[category]
    ?? 'Edit only the requested feature. Preserve everything else about the face at pixel level.';

  const geoBlock = anchors.length
    ? `\nMEASURED IDENTITY ANCHORS — preserve exactly:\n${anchors.map(g => `- ${g}`).join('\n')}\n`
    : '';

  // Beard-aware note: when removing or changing facial hair, Flux has to
  // "imagine" the skin underneath. Give it the measured jaw explicitly so
  // it doesn't fill in a generic jaw.
  const beardNote = (category === 'beard' || category === 'facial_hair')
    ? `\nNOTE ON HIDDEN GEOMETRY: the jaw beneath any beard is ${anchors.find(a => a.startsWith('jaw angle')) ?? 'as measured'}. Use this when rendering.\n`
    : '';

  return `Edit this photo to show the EXACT SAME PERSON with this single change: "${styleRequest}".

${guidance}
${geoBlock}${beardNote}
CRITICAL — preserve at pixel level:
- SAME PERSON. Same apparent age. Same ethnicity. Same skin tone.
- Bone structure, eye shape/size/colour, nose shape, lip shape, chin, jawline geometry.
- Everything NOT named in the edit request.
- Pose, angle, expression, lighting quality, background.

ABSOLUTE FAIL CONDITIONS:
- DO NOT age the subject (no wrinkles, no thinning, no greying unless that's the request).
- DO NOT make the subject look less attractive. The edit should read as a realistic improvement, never a downgrade.
- DO NOT apply plastic/filter smoothing. Natural skin texture stays.
- DO NOT change bone structure or facial identity. If unsure, err toward preserving.
- DO NOT stylise. No painterly, no HDR, no oversaturation.
- DO NOT generate a DIFFERENT person who merely resembles the subject.

STYLE: photorealistic portrait photography. Natural daylight. Same pose, same angle, same expression. Shot on 85mm lens, f/2.8.

SUCCESS TEST: the viewer must say "that's the exact same person, just with [${styleRequest}]". If the viewer says "looks similar" or "different person" — the edit has failed.`;
}
