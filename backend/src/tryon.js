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

  return `Edit this photo to show the EXACT SAME PERSON at their best with this single change: "${styleRequest}".

This should feel like the person had a great salon / barber / stylist visit and is now back home, well-rested, in flattering natural light. Same face. Same identity. Same age. BETTER presentation.

## CORE RULE — LIGHTING OVER MORPHING
The lift must come from grooming, lighting, and shadow work — NEVER from morphing bone structure or altering facial geometry. Success test: the user must say "that's literally me, just better" — not "that's AI."

${guidance}
${geoBlock}${beardNote}
IDENTITY — preserve at pixel level:
- SAME PERSON. Same apparent age (or 1-2 years younger, never older).
- Same ethnicity. Same natural skin tone.
- Bone structure, eye shape/size/colour, nose shape, lip shape, chin, jawline.
- Everything NOT named in the edit request stays identical.
- Pose, angle, expression, lighting quality, background.

APPLY ALONGSIDE THE EDIT — subtle lifts that make the twin desirable:
- Clean, healthy skin tone. No blemishes but keep natural texture.
- Bright rested eyes, no puffiness.
- Flattering soft daylight.
- Well-groomed version (hair tidy, beard neat if present).

ABSOLUTE FAIL CONDITIONS:
- DO NOT age the subject. No new wrinkles, no thinning hair, no greying unless it's the request.
- DO NOT make the subject look less attractive. The render is a glow-up, not a downgrade.
- DO NOT apply plastic / filter / glass smoothing. Natural pores stay.
- DO NOT change bone structure or facial identity.
- DO NOT stylise — no painterly, no HDR, no oversaturation.
- DO NOT render a DIFFERENT person who merely resembles the subject.
- DO NOT render lifeless or emotionless — energy matches the source.

STYLE: photorealistic portrait photography. Natural soft daylight (window or golden hour). Shot on 85mm lens, f/2.8. Modern editorial portrait quality.

SUCCESS TEST: the person seeing this should say "that's me after a great day and a fresh [${styleRequest}]". If they say "that's not me" → identity drifted. If they say "I look worse" → improvements not applied. Both fail.`;
}
