import Replicate from 'replicate';
import crypto from 'node:crypto';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Render a single-feature edit on the user's face (haircut / beard /
 * glasses / skin / etc.) while preserving identity.
 *
 * TUNING NOTES (updated after consistency audit):
 *
 * 1. Prompt length kept under ~140 words. Flux Kontext is an image-editing
 *    model — long prompts cause it to flip between contradictory
 *    instructions. Short + declarative + one change = reliable output.
 *
 * 2. `styleRequest` MUST describe the VISUAL outcome ("clear even skin
 *    with reduced texture"), NEVER the protocol ("tretinoin 0.025%
 *    nightly"). If a protocol leaks in, Flux obediently renders it —
 *    that's the "cream on face instead of retinol glow" bug. The caller
 *    (report screen, chat screen) is responsible for passing the visual
 *    phrase.
 *
 * 3. Seed: deterministic hash of image + style + category. Same input →
 *    same render every time, so the user's second tap on "See It" doesn't
 *    produce a different face.
 */
export async function tryOn({ imageBase64, styleRequest, category, geometry }) {
  if (!styleRequest || typeof styleRequest !== 'string') {
    throw new Error('styleRequest required');
  }

  const prompt = buildPrompt({ styleRequest, category });
  const seed   = deterministicSeed(imageBase64, styleRequest, category);

  const input = {
    prompt,
    input_image: `data:image/jpeg;base64,${imageBase64}`,
    aspect_ratio: 'match_input_image',
    output_format: 'jpg',
    safety_tolerance: 2,
    prompt_upsampling: false,
    seed,
  };

  const output = await replicate.run(MODEL, { input });
  const url = typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));

  return { url, prompt, styleRequest, category, seed };
}

function buildPrompt({ styleRequest, category }) {
  // One-sentence scope clause per category — tells Flux which zone is
  // editable and which must not move.
  const scope = {
    haircut:     'Edit only the head hair.',
    beard:       'Edit only the facial hair. Do not alter the jaw beneath, even if it was previously hidden.',
    facial_hair: 'Edit only the facial hair.',
    hair_color:  'Edit only the hair colour; keep the cut identical.',
    glasses:     'Edit only the eyewear; do not age the subject.',
    weight:      'Show only a subtle natural change in facial fat, under 8%. Bone structure must not move.',
    skin:        'Edit only the skin tone and texture. Keep natural pores.',
  }[category] ?? 'Edit only the requested feature.';

  // ≤140 words. One change clause + scope + identity clause + style.
  return `Same person in the photo with this single change: ${styleRequest}.

${scope}

Keep exact identity: same face, same apparent age (never older), same ethnicity and skin tone, same eye shape, same nose, same lips, same bone structure, same jawline, same pose, same expression, same framing. Do not morph facial geometry. Do not apply plastic or filter smoothing — natural skin texture and pores stay.

Photorealistic portrait, 85mm lens at f/2.8, natural soft daylight, editorial magazine quality.`;
}

function deterministicSeed(imageBase64, styleRequest, category) {
  const hash = crypto.createHash('md5')
    .update(imageBase64)
    .update('::')
    .update(styleRequest)
    .update('::')
    .update(category ?? '')
    .digest();
  return hash.readUInt32BE(0) % 2147483647;
}
