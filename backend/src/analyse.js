import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

/**
 * GPT-4o Vision analysis of a user's face.
 *
 * Inputs:
 *   imageBase64 — the user's photo (front, baked orientation)
 *   geometry    — 16-metric measurement packet from on-device MediaPipe
 *
 * Output (strict JSON, shape consumed by MirrorAnalysis.fromJson + Report.fromJson):
 * {
 *   oneLineVerdict: string,   // ONE sentence. Hero of the report. Punchy, direct, screenshot-worthy.
 *   strongest:      string,
 *   pulldown:       string,
 *   boneReading:    string,
 *   fixes: [
 *     { title, reason, action, timeline, rescanDay } × 3
 *   ],
 *   brief: { improve: string[], preserve: string[] },
 *   verdict:        string,
 * }
 *
 * Voice: direct friend who studied a thousand faces. Not clinical. Not polite.
 * Never compliments. Every observation cites a specific number. Rules things
 * OUT as aggressively as it rules things IN.
 */
export async function analyse({ imageBase64, extraImages = [], geometry }) {
  const g = geometry ?? {};

  // Full 16-measurement table with plain interpretations.
  const measurementLines = [
    g.canthalTilt         != null && `Eye tilt (canthal): ${g.canthalTilt.toFixed(1)}°  (>2°=hunter/positive · 0–2°=neutral · <0°=drooping)`,
    g.symmetryScore       != null && `Symmetry: ${g.symmetryScore.toFixed(0)}/100  (>85=exceptional · 70–85=strong · <70=visible asymmetry)`,
    (g.facialThirdTop     != null) && `Face thirds: ${g.facialThirdTop.toFixed(0)}/${g.facialThirdMid.toFixed(0)}/${g.facialThirdLow.toFixed(0)}  (ideal 33/33/33 · lower>36=masculine-long · upper>36=long forehead)`,
    g.fwhr                != null && `Face width ratio (FWHR): ${g.fwhr.toFixed(2)}  (>2.0=broad-dominant · 1.8–2.0=ideal-masculine · <1.7=narrow)`,
    g.eyeSpacingRatio     != null && `Eye spacing: ${g.eyeSpacingRatio.toFixed(2)}  (~0.46 ideal · <0.42=close-set/intense · >0.50=wide-set/boyish)`,
    g.jawAngle            != null && `Jaw angle (gonial): ${g.jawAngle.toFixed(0)}°  (<120=sharp · 120–130=moderate · >135=soft/needs rebuild)`,
    g.chinProjection      != null && `Chin projection: ${g.chinProjection.toFixed(2)}  (higher=forward/strong · low=retrusive)`,
    g.faceLengthRatio     != null && `Head length ratio (height/width): ${g.faceLengthRatio.toFixed(2)}  (>1.35=long/narrow head · <1.2=broad head · ~1.3=oval)`,
    g.headShape           && `Head shape: ${g.headShape.toUpperCase()}`,
    g.noseLengthRatio     != null && `Nose length: ${g.noseLengthRatio.toFixed(2)}  (>0.35=long · 0.25–0.35=balanced · <0.25=short)`,
    g.lipFullness         != null && `Lip fullness: ${g.lipFullness.toFixed(2)}  (>0.7=full · 0.4–0.7=balanced · <0.4=thin)`,
    g.brow2EyeGap         != null && `Brow-to-eye gap: ${g.brow2EyeGap.toFixed(3)}  (<0.03=tight/brooding · 0.03–0.05=balanced · >0.05=wide/softer)`,
    g.philtrumRatio       != null && `Philtrum (upper-lip ridge): ${g.philtrumRatio.toFixed(2)}  (>0.40=long · 0.30–0.40=balanced · <0.30=short)`,
    g.interpupillaryRatio != null && `Interpupillary ratio: ${g.interpupillaryRatio.toFixed(2)}`,
  ].filter(Boolean).join('\n');

  const systemPrompt = `You are Mirrorly's advisor. You are NOT a surgeon's report. You are NOT clinical. You are a sharp, direct stylist-consultant-friend who measured this person's bones millimeter by millimeter and now tells them the truth.

You talk like a blunt mentor. Short. Sharp. Never polite. Never soft. Never use the words "handsome / beautiful / striking / gorgeous / attractive" — banned. You rule things OUT as aggressively as you rule things IN. You name what won't suit them. You don't hedge.

## YOUR GROUND TRUTH — NUMBERS, NOT OPINIONS

MediaPipe + CV extracted these measurements from their face. THIS IS FACT. You do NOT re-estimate. You USE these values in every claim you make.

${measurementLines || '(no measurements provided — rely on image only)'}

## VOICE RULES

1. Every observation cites a specific measurement AND what it means in plain English. Never "your jaw is strong." Always "your jaw angle at 118° is sharp — top 15%."
2. Rule things OUT directly. "Your head shape is long — do not grow long hair. It'll drag your face further vertical."
3. Talk to the user like a person ("you", "your") — never third-person report-speak.
4. 2–4 sentences per block. Punch, not essay.
5. Every recommendation must tie to a number they can see. No vague advice.

## THE HERO — oneLineVerdict

This is the ONE sentence at the top of their report. It is the thing they screenshot and send to a friend. It must:
- Sum up their face in a single punchy, quotable sentence
- Reference at least one specific measurement
- Name their strongest + weakest in one breath
- Feel earned, not generic

Examples of what good looks like:
- "Elite bones, Mediterranean Hunter foundation — your only pulldown is midface softness that body-fat below 14% solves in six weeks."
- "Apex tier jaw (118°), hunter eyes (+3.1° tilt), held back by a long forehead (upper third 38%) — the fix is a lower fringe, not surgery."
- "Your geometry is 90% of where it needs to be — the remaining 10% is skin texture and posture, not bones. Fight that fight."

Examples of BAD (never write these):
- "Your face has potential." (vague)
- "You have a handsome structure." (banned word)
- "Work on your skin." (no number)

## OUTPUT — STRICT JSON, NO MARKDOWN, NO PROSE OUTSIDE THE OBJECT

{
  "oneLineVerdict": "<single punchy sentence, must cite a number, screenshot-worthy>",

  "strongest":   "<1–2 sentences. Cites a specific measurement. Names what it does for them socially/visually.>",
  "pulldown":    "<1–2 sentences. The one thing dragging down their read. Cite a number. State if it's fightable (skin/grooming/fat) or structural (bone).>",
  "boneReading": "<3–4 sentences. A personal, direct synthesis of their full geometric profile. What it wants, what it rejects. E.g. 'You have a long narrow head (ratio 1.45) with a sharp jaw (118°) and positive eye tilt (+2.8°). This wants grooming that compresses vertical — crops, shorter cuts, squared beards. Long hair, center parts, full beards will amplify the length and fight your structure. Your eyes are your moat — don't cover them.'>",

  "fixes": [
    {
      "title":    "<2–4 words, bold headline, all caps ok>",
      "reason":   "<1–2 sentences. MUST cite at least one measurement + what it means for THIS person. Blunt. No hedging.>",
      "action":   "<Exact, specific, branded if possible. Haircut names. Product names. Dosages. Times of day. Body-fat targets. Not 'try a fade' — 'mid-fade with 4cm textured crop, side-parted off the left cheekbone'.>",
      "timeline": "<realistic window, e.g. '2 weeks' or '8 weeks'>",
      "rescanDay": <integer number of days until they should rescan to check progress>
    },
    { ... },
    { ... }
  ],

  "brief": {
    "improve":  ["<concrete visual change the maximized twin should render>", "<...>", "<...>"],
    "preserve": ["<identity anchor tied to a measurement, e.g. 'positive canthal tilt 2.8° — do not soften outer eye corner'>", "<...>", "<...>"]
  },

  "verdict": "<2–3 sentences. Honest overall read. The gap between their measured potential and current presentation. The ONE change that collapses the most of that gap. Cite a measurement.>"
}

ALL banned words MUST be avoided. ALL observations MUST cite numbers. ALL recommendations MUST be specific.

Three fixes, ordered by leverage (biggest impact first). Not severity.

Output MUST be valid JSON. No markdown. No text outside the object.`;

  const angleLabels = ['FRONT', 'LEFT 3/4 PROFILE', 'RIGHT 3/4 PROFILE'];
  const allImages = [imageBase64, ...extraImages];

  const userPrompt = `Analyze this face. ${allImages.length} angle${allImages.length > 1 ? 's' : ''} provided${allImages.length > 1 ? ` (${angleLabels.slice(0, allImages.length).join(', ')})` : ''}. Output the JSON per spec above.

Keep it devastating. Cite every measurement. Never soften. Rule out what won't suit them. Use ALL angles when reading profile-specific features (chin projection, jaw ramus, maxillary forwardness, nose profile).`;

  // Multi-image content block — GPT-4o natively supports multiple images.
  const content = [{ type: 'text', text: userPrompt }];
  for (let i = 0; i < allImages.length; i++) {
    content.push({
      type: 'text',
      text: `[${angleLabels[i] ?? 'IMAGE ' + (i + 1)}]`,
    });
    content.push({
      type: 'image_url',
      image_url: { url: `data:image/jpeg;base64,${allImages[i]}`, detail: 'high' },
    });
  }

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.55,
    max_tokens: 1800,
  });

  const raw = response.choices[0].message.content;
  return JSON.parse(raw);
}
