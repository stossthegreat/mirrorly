import Replicate from 'replicate';
import crypto from 'node:crypto';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Single-change edit on the user's face (haircut / beard / skin / glasses
 * / whatever they typed). Identity-locked per BFL's Kontext i2i guide.
 *
 *   docs.bfl.ai/guides/prompting_guide_kontext_i2i
 *
 * THE KEY FIX (vs previous version):
 * Preservation clauses are now CATEGORY-AWARE. Saying "preserve the face"
 * isn't enough because Kontext takes it as permission to "improve the
 * face overall" — shortening hair, trimming beard, lightening skin
 * alongside the requested edit. The only way to pin a single-zone edit is
 * to ENUMERATE what must stay identical, including the other features
 * Kontext might otherwise "also improve." A haircut request now explicitly
 * tells Flux to preserve the beard. A beard request tells it to preserve
 * the haircut. Etc. This is the documented way to get single-zone edits.
 *
 * styleRequest is passed VERBATIM. Caller guarantees it's a VISUAL phrase
 * describing the end state (never protocol: "tretinoin nightly" → cream
 * on face). Report screen's fix card sources it from Fix.visualRequest;
 * chat from style_request. Both are schema-constrained to single-zone.
 *
 * Seed: deterministic hash of image + style + category. Same input →
 * same render every run.
 */
export async function tryOn({ imageBase64, styleRequest, category }) {
  if (!styleRequest || typeof styleRequest !== 'string') {
    throw new Error('styleRequest required');
  }

  const normalizedCategory = normalizeCategory(category);
  const prompt = buildPrompt({
    styleRequest: styleRequest.trim(),
    category:     normalizedCategory,
  });
  const seed = deterministicSeed(imageBase64, styleRequest, normalizedCategory);

  const input = {
    prompt,
    input_image: `data:image/jpeg;base64,${imageBase64}`,
    aspect_ratio: 'match_input_image',
    output_format: 'png',
    output_quality: 95,
    safety_tolerance: 2,
    prompt_upsampling: false,
    seed,
  };

  const output = await replicate.run(MODEL, { input });
  const url = typeof output === 'string'
    ? output
    : (output?.url?.() ?? output?.[0] ?? String(output));

  return { url, prompt, styleRequest, category: normalizedCategory, seed };
}

/**
 * Canonical category list. Anything we don't recognise is treated as a
 * generic "face" edit with a conservative preservation clause.
 */
function normalizeCategory(c) {
  const allowed = new Set([
    'haircut', 'hair_color',
    'beard', 'facial_hair',
    'eyebrow',
    'skin',
    'glasses',
    'weight',
    'teeth',
  ]);
  return allowed.has(c) ? c : 'generic';
}

/**
 * buildPrompt — BFL-canonical structure + ONE category-specific
 * sibling-lock clause.
 *
 * Kontext's attention budget is finite. Before, we shipped a long
 * enumerated preservation list per category ("keep the beard, keep the
 * hair, keep the skin, keep the eyes, keep the nose, keep the lips,
 * keep the jaw, keep the ethnicity, keep the age...") — that length
 * dilutes the signal and actually hurts identity preservation.
 *
 * The structure here is:
 *   1. Subject + single change (BFL canonical opener, no pronouns)
 *   2. BFL's canonical 7-word preservation formula + identity anchors
 *   3. ONE short sibling-lock sentence naming the adjacent zone
 *      Kontext is most likely to drift for this category (e.g. a
 *      haircut run most commonly drifts the beard; a beard run drifts
 *      the haircut). One sentence, not a list.
 *   4. Pose/lighting/background lock
 *
 * Positive-only (no "do not" — BFL: negatives can invert intent).
 */
function buildPrompt({ styleRequest, category }) {
  const sibling = siblingLock(category);

  return `The person in this photo, now with ${styleRequest.replace(/^(make\s+|apply\s+)/i, '')}, while maintaining the same facial features, hairstyle, expression, age, skin tone, and ethnicity.${sibling ? ' ' + sibling : ''} Same pose, camera angle, framing, lighting, and background as the original. Photorealistic, natural pores preserved.`;
}

/**
 * The ONE adjacent zone Kontext most commonly drifts per category.
 * Short, declarative, positive. No list.
 */
function siblingLock(category) {
  switch (category) {
    case 'haircut':
    case 'hair_color':
      return 'The facial hair stays exactly as in the original.';
    case 'beard':
    case 'facial_hair':
      return 'The hair on the head stays exactly as in the original.';
    case 'skin':
      return 'The hair on the head and the facial hair stay exactly as in the original.';
    case 'eyebrow':
      return 'The hair on the head, facial hair, and skin stay exactly as in the original.';
    case 'glasses':
    case 'teeth':
    case 'weight':
      return 'Every other feature stays exactly as in the original.';
    default:
      return 'Every other feature stays exactly as in the original.';
  }
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
