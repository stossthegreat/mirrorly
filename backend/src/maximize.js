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

  return `Produce the BEST-looking version of the SAME person in this photo. Not a filter. Not a different person. The same exact human — but visibly BETTER than the source image. Significantly better. If the output doesn't look distinctly more attractive than the input, the render has failed.

## THE CORE RULE — LIGHTING OVER MORPHING

The entire lift must come from:
- Better lighting (soft warm daylight, flattering contours)
- Clean skin (even tone, reduced texture WITHOUT plastic blur)
- Tidy grooming (neat hair, shaped brows, trimmed beard if present)
- Subtle shadow work (under-jaw contour, upper-lid depth)

The lift MUST NOT come from:
- Enlarging eyes
- Narrowing nose
- Sharpening bone structure
- Reshaping lips
- Any morphing of facial geometry

Lighting and grooming can create the PERCEPTION of sharper features without altering the underlying identity. That is the only allowed path.

## PER-FEATURE VISUAL RULES

EYES: slight contrast increase around eyes, deepened upper-lid shadow, darker lash line, reduced under-eye dullness. DO NOT enlarge eyes. DO NOT make them glossy.

JAW: tightened beard edges if beard present, reduced beard bulk, subtle shadow under jawline, slight contrast between neck and jaw. DO NOT morph bone structure.

FACE BALANCE: slightly darken lower third if long-lower, add hair volume on top if needed. DO NOT stretch or compress face geometry.

HAIR: slight volume at top, defined direction, darkened roots for density. DO NOT change hairstyle radically. DO NOT add unrealistic hair.

SKIN: reduce harsh texture slightly, even tone subtly, KEEP PORES VISIBLE. DO NOT blur. DO NOT remove all imperfections. Target: "healthier, not edited."

SYMMETRY: micro-adjust alignment only — barely visible. DO NOT mirror face. DO NOT make it uncanny.

LIPS: slight tone balance, subtle edge clarity. DO NOT increase size. DO NOT change shape.

## STACKING RULE

When multiple fixes are applied together, BLEND them at ~70% strength each instead of 100%. Stacking at full intensity breaks realism.


Imagine this person: walked out of a top salon, two weeks of great sleep, a clean skincare routine on week six, shot by an editorial portrait photographer in golden-hour window light. That is your target output. Same face — but the obvious visual improvement a viewer would notice immediately.

This is NOT cosmetic surgery. NOT altered bone structure. NOT a filter look. It is the person at the absolute peak of what is achievable through grooming, skincare, lighting, hair, and health — applied maximally.
${geoBlock}
APPLY ALL OF THESE LIFTS — combine them, don't pick one:
${improveList.map(i => `- ${i}`).join('\n')}

Additional maximization — apply these even if not listed above:
- The hairstyle that best suits their measured head shape and face length (if long face: compression cut with height; if broad: taller top, tighter sides; if oval: mid-fade with texture). Cleanly styled and shot.
- Skin distinctly clearer and more even than the source — no blemishes, uniform tone, healthy glow. Keep natural pores.
- Bright, clearly rested eyes. No dark circles, no puffiness.
- Well-defined, neatly groomed brows matching their face structure.
- If bearded in source: beard perfectly trimmed and shaped to their jaw geometry. If clean-shaven in source: stay clean-shaven.
- Flattering warm daylight catching the cheekbones.
- Slight subtle leanness if appropriate — the face 5–8% tighter, never gaunt.
- Overall: obvious, visible upgrade the user will post on social media.

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

SUCCESS TEST — the person viewing their twin should say: "that's me, but visibly BETTER — I want to look like that."

If they say "that's not me" → identity drifted. FAIL.
If they say "I look the same / look worse" → improvements not applied forcefully enough. FAIL.
The target: clear, visible, aspirational lift the user would screenshot and share.

RENDER WITH CONFIDENCE. Apply all improvements in combination, not timidly. This is their ASPIRATIONAL twin — the version they'd pay for. Make it a real glow-up while preserving every identity anchor listed above.`;
}
