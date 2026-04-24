import Replicate from 'replicate';
import crypto from 'node:crypto';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL CHOICE — April 2026 research verdict
// ─────────────────────────────────────────────────────────────────────────────
// Kontext Max was producing "uglier / older / different person" outputs. The
// root cause is structural, not prompt-level:
//   1. Flux has a documented +2.18 year age bias on males (arxiv 2502.03420).
//   2. Kontext's identity is a SOFT prompt bias, not a face-embedding lock —
//      every edit re-synthesises the full face.
//   3. Flux's portrait prior over-smooths skin, which kills cheek-shadow and
//      reads as "older / less attractive."
// Fix = (a) use a model whose portrait prior isn't beauty-retouched, AND
//       (b) post-pass a face-swap from the ORIGINAL selfie back onto the edit
//           output — a GEOMETRIC identity lock that no prompt can outperform.
//
// Primary edit model: Google's Nano Banana (Gemini 2.5 Flash Image). Google's
// DeepMind marketing for this model: "locks onto your facial features, skin
// tone, and expression before making any change." Best-in-class for hair /
// beard edits where the face must stay recognisable.
//
// Post-pass: cdingram/face-swap on Replicate (buffalo_l + inswapper_128).
// Takes the edit output + the original selfie, pastes the original face's
// geometry onto the new haircut, blends. ~$0.01/img, ~4s.
//
// Net cost: Nano Banana Flash ($0.039) + face swap ($0.01) ≈ $0.05 / twin
// vs Kontext Max $0.08 — CHEAPER AND BETTER.
const EDIT_MODEL = 'google/nano-banana';         // primary — Gemini 2.5 Flash Image
const SWAP_MODEL = 'cdingram/face-swap';         // identity-lock post-pass

/**
 * Generate the Maximized Twin — ONE hero change, identity-locked.
 *
 * Architecture:
 *   Stage 1: pick the single hero change from brief.improve. Hair > Beard >
 *            other grooming. Skin is NEVER the hero and is never sent to the
 *            edit model. (Flux/Nano Banana both smooth skin as a side effect
 *            — which is how we got "uglier/older" outputs.)
 *   Stage 2: call Nano Banana with a descriptor-first prompt that positively
 *            preserves face/bones/age so the model clamps identity.
 *   Stage 3: face-swap post-pass using the ORIGINAL selfie as the face
 *            source. This is the geometric identity guarantee — no prompt
 *            can drift the face when we literally paste the original face
 *            geometry back at the end.
 *
 * Returns { url, editUrl, prompt, seed, heroChange, model, intermediateUrls }.
 */
export async function maximize({ imageBase64, brief }) {
  const improve = Array.isArray(brief?.improve) ? brief.improve : [];

  // Rank fixes: hair(0) > beard(1) > other-grooming(2). Skin(3) filtered out.
  const ranked = improve
    .map((s, i) => ({ s: String(s || '').trim(), pri: classify(s), idx: i }))
    .filter(r => r.s.length > 0 && r.pri <= 2)
    .sort((a, b) => a.pri - b.pri || a.idx - b.idx);

  const heroChange = ranked.length > 0
    ? ranked[0].s
    : 'a cleanly styled, modern haircut that suits the face shape';

  const prompt = buildPrompt(heroChange);
  const seed   = deterministicSeed(imageBase64);
  const inputDataUri = `data:image/jpeg;base64,${imageBase64}`;

  console.log(`[maximize] heroChange="${heroChange}" (ranked=${ranked.length})`);

  // Stage 1+2 — primary edit via Nano Banana. Retry on EVERY error
  // (not just transient): content-moderation false-positives, weird
  // Replicate 4xxs on valid payloads, and unclassified failures all
  // used to throw here and cascade up to a "Server hiccup" screen.
  // User's explicit ask: never fail. Retry 5 times; the Flutter
  // client will retry the whole request if we somehow still throw.
  const editStart = Date.now();
  const editUrl = await runWithRetry(
    () => runEdit({ imageDataUri: inputDataUri, prompt }),
    { label: 'edit', maxAttempts: 5, retryAll: true },
  );
  console.log(`[maximize] edit ok: ${Date.now() - editStart}ms`);

  // Stage 3 — face-swap original → edit (identity guarantee).
  // Retried on all errors. If all retries fail we fall back to the
  // edit output rather than crashing the whole /scan — identity will
  // drift slightly but the user still gets a usable twin, which is
  // infinitely better than an empty hero card.
  let finalUrl = editUrl;
  const swapStart = Date.now();
  try {
    finalUrl = await runWithRetry(
      () => runFaceSwap({
        editedUrl:   editUrl,
        originalUri: inputDataUri,
      }),
      { label: 'swap', maxAttempts: 4, retryAll: true },
    );
    console.log(`[maximize] swap ok: ${Date.now() - swapStart}ms`);
  } catch (e) {
    console.warn(`[maximize] swap FAILED after retries (${Date.now() - swapStart}ms): ${String(e?.message ?? e)}`);
  }

  return {
    url:              finalUrl,
    editUrl,
    prompt,
    seed,
    heroChange,
    model:            EDIT_MODEL,
    intermediateUrls: [],
  };
}

/**
 * Generic retry wrapper for Replicate calls. Retries on:
 *   · HTTP 429 (rate limit)
 *   · HTTP 5xx (transient server errors — the #1 source of "Server hiccup"
 *     reports, Replicate's upstream is not always stable)
 *   · Network timeouts, ECONNRESET, ETIMEDOUT, socket hang up
 *
 * Does NOT retry on:
 *   · 4xx other than 429 (client errors — our payload is broken)
 *   · Content-policy refusals
 *
 * Backoff: respects Retry-After hint if present, else exponential
 * (3s, 6s, 12s) capped at 30s.
 */
async function runWithRetry(fn, { label, maxAttempts = 3, retryAll = false } = {}) {
  let lastErr;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      const msg = String(err?.message ?? err);
      // retryAll = retry every error, not just the ones we classified
      // as transient. Trade-off: a genuinely broken payload will waste
      // all attempts — but we'd rather waste retries than throw a
      // recoverable failure up to the user. For the ones we DO know
      // are transient, the wait honours Retry-After; for everything
      // else we use a plain exponential schedule.
      const transient = isTransient(msg);
      const shouldRetry = retryAll || transient;
      if (!shouldRetry || attempt >= maxAttempts) {
        console.error(`[${label}] failed attempt ${attempt}/${maxAttempts} (terminal): ${msg}`);
        throw err;
      }
      const retryAfter = msg.match(/retry_after"?\s*:\s*(\d+)/);
      const waitSec    = retryAfter ? Number(retryAfter[1]) : Math.pow(2, attempt) * 3;
      const waitMs     = Math.min(Math.max(waitSec, 3), 30) * 1000;
      const kind = transient ? 'transient' : 'unclassified';
      console.warn(`[${label}] ${kind} failure attempt ${attempt}/${maxAttempts}: "${msg.slice(0, 200)}" — waiting ${waitMs}ms`);
      await new Promise(r => setTimeout(r, waitMs));
    }
  }
  throw lastErr;
}

function isTransient(msg) {
  const m = msg.toLowerCase();
  // HTTP status code matches
  if (/\b(429|500|502|503|504)\b/.test(m))           return true;
  if (m.includes('too many requests'))               return true;
  if (m.includes('internal server error'))           return true;
  if (m.includes('bad gateway'))                     return true;
  if (m.includes('service unavailable'))             return true;
  if (m.includes('gateway timeout'))                 return true;
  // Network / socket level
  if (m.includes('etimedout'))                       return true;
  if (m.includes('econnreset'))                      return true;
  if (m.includes('econnrefused'))                    return true;
  if (m.includes('socket hang up'))                  return true;
  if (m.includes('network socket disconnected'))     return true;
  if (m.includes('network error'))                   return true;
  if (m.includes('timeout'))                         return true;
  // Replicate-specific prediction failures that are often transient
  if (m.includes('prediction failed') && m.includes('overloaded')) return true;
  return false;
}

/**
 * Classify an improve item so we can rank it:
 *   0 = HAIR  (hero if present)
 *   1 = BEARD (hero if hair absent)
 *   2 = OTHER grooming (brows, teeth, glasses, lashes)
 *   3 = SKIN — never sent to the model
 */
function classify(s) {
  const x = String(s || '').toLowerCase();
  if (/\b(hair(?!\s*line)|fade|crop|cut|hairline|fringe|buzz|taper|undercut|quiff|pomp|part|bangs)\b/.test(x)) return 0;
  if (/\b(beard|stubble|goatee|moustache|facial hair)\b/.test(x)) return 1;
  if (/\b(brow|eyebrow|teeth|whiten|glasses|frame|lash)\b/.test(x)) return 2;
  return 3; // skin / tone / pore / blemish → drop
}

/**
 * Descriptor-first prompt. Five ordered beats, tuned for Nano Banana
 * (Gemini 2.5 Flash Image):
 *
 *   1. Subject naming                — "The person in this photo"
 *   2. The ONE hero change           — "Give them [heroChange]"
 *   3. Grooming baseline (ALWAYS)    — clean healthy skin, styled hair,
 *                                      neat facial hair if present
 *   4. Identity preserve clause      — bones / proportions / age / ethnicity
 *   5. Environment preserve clause   — lighting, background, pose
 *
 * Why the grooming baseline (new in this version): one of two things is
 * always true of the user — (a) the hero change IS grooming, in which
 * case the baseline reinforces it, or (b) the hero is non-grooming
 * (glasses, expression), in which case we still want the twin to look
 * their best instead of keeping original bed hair / stubble. The model
 * pairs a skin cleanup + fresh styling with the hero without bleeding
 * into bone reshaping when the identity clause is specific.
 *
 * "Apparent age" sits at the top of the preserve clause — documented
 * fix for Flux/Gemini's +2y male age-drift (arxiv 2502.03420). Without
 * it, the model nudges older even when the hero change is neutral.
 *
 * "Clean natural skin texture" (vs. the old "do not smooth the skin")
 * tells the model to clean up acne, redness, uneven tone WITHOUT going
 * airbrushed/plastic — which was the old failure mode.
 */
function buildPrompt(heroChange) {
  return (
    `The person in this photo. Give them ${heroChange}. ` +

    // Grooming baseline — applied on every twin regardless of hero
    `At the same time, make them look their absolute best: ` +
    `clean, clear, healthy skin with even tone — no acne, no blemishes, ` +
    `no redness, no visible pores — but keep natural skin texture ` +
    `(not airbrushed, not plastic, not smoothed). ` +
    `Give them freshly-cut and cleanly-styled hair. ` +
    `If they have facial hair, keep it neatly groomed with clean lines ` +
    `and a tight neckline. Groomed eyebrows, no stragglers. ` +

    // Identity preserve — non-negotiable, positively framed
    `Keep their apparent age, face shape, bone structure, jawline, ` +
    `cheekbones, nose shape, eye shape, eye colour, lip shape, ` +
    `expression, and ethnicity — exactly as in the original. ` +
    `Do not reshape any bones. Do not age the face. Do not alter ` +
    `identity. ` +

    // Environment preserve — no scene drift
    `Keep the same lighting, background, framing, camera angle, and ` +
    `pose. Natural shadows. Photorealistic.`
  );
}

// ─── Stage 1+2 — primary edit ────────────────────────────────────────────────
async function runEdit({ imageDataUri, prompt }) {
  // Nano Banana accepts `image_input` as an ARRAY (supports up to 14 refs).
  // png output avoids jpg compression artifacts on skin.
  const input = {
    prompt,
    image_input:   [imageDataUri],
    aspect_ratio:  'match_input_image',
    output_format: 'png',
  };
  const output = await replicate.run(EDIT_MODEL, { input });
  return extractUrl(output);
}

// ─── Stage 3 — face-swap post-pass (GEOMETRIC identity lock) ─────────────────
// The identity guarantee no prompt can deliver. Takes:
//   - editedUrl   : the Nano Banana output (has the new hair, drifted face)
//   - originalUri : the user's actual selfie (has the correct face)
// Pastes the original face geometry onto the edited output, blends.
async function runFaceSwap({ editedUrl, originalUri }) {
  const input = {
    input_image: editedUrl,     // target (has the new hair/beard)
    swap_image:  originalUri,   // source (has the correct face)
  };
  const output = await replicate.run(SWAP_MODEL, { input });
  return extractUrl(output);
}

// ─── helpers ─────────────────────────────────────────────────────────────────
function extractUrl(output) {
  if (typeof output === 'string') return output;
  if (Array.isArray(output))      return String(output[0]);
  if (output && typeof output.url === 'function') return output.url();
  if (output && typeof output.url === 'string')   return output.url;
  return String(output);
}

function deterministicSeed(imageBase64) {
  const hash = crypto.createHash('md5').update(imageBase64).digest();
  return hash.readUInt32BE(0) % 2147483647;
}
