import Replicate from 'replicate';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Generate the Maximized Twin — the SAME person, visibly at their best day.
 *
 * Hard-won tuning:
 * - Identity-preserve prompts alone produce "same person, no visible upgrade."
 *   The user sees themselves copied + slightly worse and feels bad.
 * - Must LEAN HARD into improvements (skin, lighting, rested look, hair
 *   tidier) while anchoring identity via measured geometry.
 * - Explicit "best day" framing gets Flux Kontext to produce the lift the
 *   user actually wants — not just a clone.
 * - YOUNGER, not older. Wrinkles / tired / aged = fail conditions.
 */
export async function maximize({ imageBase64, brief, geometry }) {
  const improve  = (brief?.improve  ?? []).slice(0, 4);
  const preserve = brief?.preserve ?? [];

  const anchors = buildAnchors(geometry);
  const prompt = buildPrompt({ anchors, improve, preserve });

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

  return { url, prompt };
}

function buildAnchors(geometry) {
  if (!geometry) return [];
  return [
    geometry.canthalTilt     != null ? `canthal tilt ${geometry.canthalTilt.toFixed(1)}°`       : null,
    geometry.fwhr            != null ? `FWHR ${geometry.fwhr.toFixed(2)}`                        : null,
    geometry.eyeSpacingRatio != null ? `eye spacing ${geometry.eyeSpacingRatio.toFixed(2)}`      : null,
    geometry.jawAngle        != null ? `jaw angle ${geometry.jawAngle.toFixed(0)}°`              : null,
    geometry.faceLengthRatio != null ? `face length ratio ${geometry.faceLengthRatio.toFixed(2)}`: null,
    geometry.headShape       ? `head shape ${geometry.headShape}` : null,
    geometry.lipFullness     != null ? `lip fullness ${geometry.lipFullness.toFixed(2)}`         : null,
    geometry.facialThirdTop  != null
      ? `thirds ${geometry.facialThirdTop.toFixed(0)}/${geometry.facialThirdMid.toFixed(0)}/${geometry.facialThirdLow.toFixed(0)}`
      : null,
  ].filter(Boolean);
}

function buildPrompt({ anchors, improve, preserve }) {
  // SAME person, but their BEST version. The improvement list is LOADED —
  // we want a visible uplift, not a pixel clone.
  const improveList = improve.length > 0 ? improve : [
    'clear, even skin with a healthy natural tone and vitality',
    'bright rested eyes, no dark circles, no puffiness',
    'tidied eyebrows, cleanly groomed hairline, neat hair',
    'subtle natural contouring from flattering soft daylight',
    'fuller natural-looking skin volume (well-rested, well-hydrated look)',
    'neatly trimmed facial hair if present — or clean smooth skin if not',
    'slightly leaner, more defined facial contours (not gaunt — healthy lean)',
  ];

  const preserveList = [
    'the EXACT SAME PERSON — same face, same identity',
    'SAME APPARENT AGE (or 1-2 years YOUNGER — never older)',
    'exact eye shape, eye colour, eye size, inter-eye distance',
    'exact nose shape, width, length',
    'exact lip shape and proportions',
    'exact bone structure, face length, face width',
    'exact ethnicity and natural skin tone',
    'exact jawline geometry (the measured angle above)',
    'exact brow position and shape',
    'same hair colour (unless explicitly changed)',
    'same beard/stubble presence (unless explicitly changed)',
    'same pose, angle, expression',
    ...preserve,
  ];

  const geoBlock = anchors.length > 0
    ? `\nMEASURED IDENTITY ANCHORS — do not alter:\n${anchors.map(g => `- ${g}`).join('\n')}\n`
    : '';

  return `Produce the best-day version of the SAME person in this photo. Imagine this person: well-rested, well-lit, clean skin, healthy colour, tidy grooming. That is what you render. Same face, same age, same identity — visibly at their peak.

This is NOT a filter. NOT a beautification. NOT a transformation. It is a believable high-quality portrait of the exact same person after 8 hours of sleep, good skincare, a fresh haircut, great lighting, and a good mood.
${geoBlock}
APPLY ALL OF THESE LIFT the presentation without touching identity:
${improveList.map(i => `- ${i}`).join('\n')}

IDENTITY — preserve at pixel level:
${preserveList.map(p => `- ${p}`).join('\n')}

ABSOLUTE FAIL CONDITIONS — these make the output unusable:
- Do NOT age the subject. No new wrinkles, no thinning hair, no greying unless they already have it.
- Do NOT make the subject look less attractive, more tired, more gaunt, or puffier.
- Do NOT apply plastic / glass / filter skin smoothing. Keep natural texture with pores.
- Do NOT enlarge eyes, narrow nose, carve jaw, or alter bone structure.
- Do NOT change ethnicity, eye colour, or identity.
- Do NOT stylise, paint, HDR, or oversaturate.
- Do NOT add symmetry perfection — natural micro-asymmetries stay.
- Do NOT change pose, angle, expression, or background beyond a clean lighting neutralisation.

STYLE: photorealistic portrait photography, shot on 85mm lens at f/2.8, natural window light, modern magazine editorial quality. Same pose, same angle, same framing.

SUCCESS TEST — the person viewing their twin should say: "that's me on a great day". If they say "that's not me" → identity drifted. If they say "I look worse" → improvements not applied. Both are failure states.`;
}
