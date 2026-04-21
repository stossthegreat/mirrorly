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
 * buildPrompt — BFL-canonical structure:
 *   1. Name the subject (no pronouns)
 *   2. State the single change
 *   3. CATEGORY-SPECIFIC preservation clause enumerating every other
 *      region Kontext must leave identical, INCLUDING the sibling
 *      regions it would otherwise "improve" on its own
 *   4. Global pose/lighting/background preservation
 *
 * No negative prompting ("do not change X") — Kontext can attend to
 * forbidden concepts and invert the intent. Only positive preservation.
 */
function buildPrompt({ styleRequest, category }) {
  const { editZone, preserveList } = zoneSpec(category);

  return `The person in this photo. Make this single change: ${styleRequest}.

Only alter ${editZone}. Keep the exact same ${preserveList} — these must remain identical to the original photo.

Preserve the original pose, camera angle, framing, facial expression, lighting, and background exactly. Natural skin texture with visible pores. Photorealistic portrait.`;
}

/**
 * For each category, list:
 *   editZone      — the spatial zone Flux is allowed to change
 *   preserveList  — every OTHER region that must stay identical, INCLUDING
 *                   the regions a naive Kontext run would drift
 *                   (e.g. haircut edits often drift beard, skin, eye tone)
 */
function zoneSpec(category) {
  switch (category) {
    case 'haircut':
      return {
        editZone: 'the hair on the head (length, style, cut)',
        preserveList:
          'facial hair (beard, moustache, stubble) exactly as-is; ' +
          'skin tone, skin texture, and complexion; ' +
          'eyes, eye colour, eye shape, eyebrows; ' +
          'nose, lips, jaw, chin, cheekbones, and overall bone structure; ' +
          'ethnicity, age, and identity',
      };

    case 'hair_color':
      return {
        editZone: 'the hair colour on the head',
        preserveList:
          'hair length, hair style, hair cut, and hairline exactly as-is; ' +
          'facial hair colour and shape; ' +
          'skin tone, eyes, eye colour, eyebrows, nose, lips, jaw, bone structure, ethnicity, age, and identity',
      };

    case 'beard':
    case 'facial_hair':
      return {
        editZone: 'the facial hair on the chin, jaw, and upper lip',
        preserveList:
          'the hair on the head (length, style, cut, colour) exactly as-is; ' +
          'skin tone and texture; ' +
          'eyes, eye colour, eyebrows, nose, lips, jaw, chin, and bone structure underneath; ' +
          'ethnicity, age, and identity',
      };

    case 'eyebrow':
      return {
        editZone: 'the eyebrow shape and grooming',
        preserveList:
          'the hair on the head and facial hair exactly as-is; ' +
          'skin tone and texture; ' +
          'eyes, eye colour, eye shape, nose, lips, jaw, bone structure, ethnicity, age, and identity',
      };

    case 'skin':
      return {
        editZone: 'the skin tone, texture, and complexion — with natural pores preserved',
        preserveList:
          'the hair on the head (length, style, cut, colour) exactly as-is; ' +
          'facial hair (beard, moustache, stubble) exactly as-is; ' +
          'eyes, eye colour, eye shape, eyebrows, nose, lips, jaw, bone structure, ethnicity, age, and identity',
      };

    case 'glasses':
      return {
        editZone: 'the eyewear (add, remove, or change frames as described)',
        preserveList:
          'the hair on the head and facial hair exactly as-is; ' +
          'skin tone and texture; ' +
          'eyes, eye colour, eye shape, eyebrows, nose, lips, jaw, bone structure, ethnicity, age, and identity',
      };

    case 'weight':
      return {
        editZone: 'the facial fat distribution very subtly (no more than 5–8% change; no bone movement)',
        preserveList:
          'the hair on the head and facial hair exactly as-is; ' +
          'skin tone and texture; ' +
          'eyes, eye colour, eyebrows, nose shape, lip shape, jaw angle, chin, cheekbone position, bone structure, ethnicity, age, and identity',
      };

    case 'teeth':
      return {
        editZone: 'only the teeth (whitening or alignment as described)',
        preserveList:
          'the hair on the head and facial hair; ' +
          'skin tone and texture; ' +
          'lip shape and lip colour; ' +
          'eyes, eye colour, eyebrows, nose, jaw, bone structure, ethnicity, age, and identity',
      };

    default: // 'generic' — conservative fallback
      return {
        editZone: 'only the specific feature named in the change above',
        preserveList:
          'every other feature of the face — the hair on the head, facial hair, skin tone and texture, eyes, eye colour, eyebrows, nose, lips, jaw, bone structure, ethnicity, age, and identity — exactly as in the original',
      };
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
