import Replicate from 'replicate';
import crypto from 'node:crypto';

const replicate = new Replicate({ auth: process.env.REPLICATE_API_TOKEN });
const MODEL = 'black-forest-labs/flux-kontext-max';

/**
 * Generate the Maximized Twin — the SAME person, visibly at their best day.
 *
 * HARD-WON TUNING (updated after consistency audit):
 *
 * Flux Kontext is an image-editing model, not a prose-comprehension LLM.
 * Black Forest Labs' own guidance: short, declarative, ≤~150 words, ONE
 * targeted change at a time. Our old prompt was ~3000 words and contained
 * contradictions ("LEAN HARD into improvements" + "preserve at pixel
 * level"). The model reconciled those by coin-flipping between them — which
 * is exactly the "sometimes perfect, sometimes old/ugly/filtered" symptom
 * users reported. Cutting to a tight prompt + seed lock resolves both.
 *
 * Seed: deterministic hash of the input image. Same photo → same render,
 * every time. Eliminates run-to-run variance for a given user at zero
 * extra cost.
 */
export async function maximize({ imageBase64, brief, geometry }) {
  const improve = (brief?.improve ?? []).slice(0, 3);
  const prompt  = buildPrompt({ improve });
  const seed    = deterministicSeed(imageBase64);

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

  return { url, prompt, seed };
}

function buildPrompt({ improve }) {
  // If GPT surfaced specific visual lifts, use those (3 max). Otherwise
  // a tight default list of four concrete, visual directives — never
  // protocol language like "tretinoin" or "sleep 8 hours".
  const improveList = improve.length > 0 ? improve : [
    'clearer, more even skin with natural pores still visible',
    'brighter, rested eyes with no dark circles',
    'cleanly groomed hair and brows matched to the face shape',
    'soft warm daylight shaping the cheekbones',
  ];

  // ≤150 words. One instruction, one preservation clause, one style modifier.
  // This is the format Flux Kontext was trained to respond to.
  return `Same person in the photo, photographed on their best day — a visibly better, more attractive version of themselves. Not a filter. Not a different person.

Subtle real-world improvements only:
${improveList.map(i => `- ${i}`).join('\n')}

Keep exact identity: same face, same apparent age (never older), same ethnicity and skin tone, same eye shape, same nose, same lips, same bone structure, same jawline geometry, same pose, same expression, same framing. Do not morph facial features. Do not apply plastic or filter smoothing. Natural skin texture and pores stay.

Photorealistic portrait, 85mm lens at f/2.8, natural window light, modern editorial magazine quality.`;
}

/**
 * Stable 32-bit unsigned seed derived from the input image bytes. Replicate
 * accepts any integer seed. Hashing the base64 gives us the property that
 * the SAME scan always produces the SAME render, without us having to
 * track state or tokens anywhere.
 */
function deterministicSeed(imageBase64) {
  const hash = crypto.createHash('md5').update(imageBase64).digest();
  // First 4 bytes → unsigned 32-bit int. Mod by 2^31 - 1 keeps it inside
  // the positive-int32 range most model backends expect.
  return hash.readUInt32BE(0) % 2147483647;
}
