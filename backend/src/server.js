import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyse } from './analyse.js';
import { maximize } from './maximize.js';
import { tryOn } from './tryon.js';
import { chat } from './chat.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);
const publicDir  = path.resolve(__dirname, '..', 'public');

const app = express();
app.use(cors());
app.use(express.json({ limit: '25mb' }));
app.use(express.static(publicDir));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'mirror-backend' });
});

// ── Vision analysis: GPT-4o takes image(s) + CV measurements → returns brief + advice
app.post('/analyse', async (req, res) => {
  try {
    const { imageBase64, extraImagesBase64, geometry } = req.body;
    if (!imageBase64) return res.status(400).json({ error: 'imageBase64 required' });
    const report = await analyse({
      imageBase64,
      extraImages: Array.isArray(extraImagesBase64) ? extraImagesBase64 : [],
      geometry,
    });
    res.json(report);
  } catch (err) {
    console.error('[/analyse] error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── Maximize: Flux Kontext takes image + improvement brief → returns maximized image URL
app.post('/maximize', async (req, res) => {
  try {
    const { imageBase64, brief, geometry } = req.body;
    if (!imageBase64) return res.status(400).json({ error: 'imageBase64 required' });
    const result = await maximize({ imageBase64, brief, geometry });
    res.json(result);
  } catch (err) {
    console.error('[/maximize] error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── Full pipeline: analyse → maximize in one call, geometry flowing through both
app.post('/scan', async (req, res) => {
  try {
    const { imageBase64, extraImagesBase64, geometry } = req.body;
    if (!imageBase64) return res.status(400).json({ error: 'imageBase64 required' });

    const report = await analyse({
      imageBase64,
      extraImages: Array.isArray(extraImagesBase64) ? extraImagesBase64 : [],
      geometry,
    });
    const maxed  = await maximize({
      imageBase64, // Flux Kontext uses the front image only for identity lock
      brief: report.brief,
      geometry,
    });

    res.json({ report, maximized: maxed });
  } catch (err) {
    console.error('[/scan] error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── Chat: face-aware advisor. Text reply + optional inline tryon render.
app.post('/chat', async (req, res) => {
  try {
    const { messages, face } = req.body;
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'messages[] required' });
    }
    const result = await chat({ messages, face: face ?? {} });
    res.json(result);
  } catch (err) {
    console.error('[/chat] error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ── Try-on: "show me with a beard / fade / glasses / etc"
app.post('/tryon', async (req, res) => {
  try {
    const { imageBase64, styleRequest, category, geometry } = req.body;
    if (!imageBase64)   return res.status(400).json({ error: 'imageBase64 required' });
    if (!styleRequest)  return res.status(400).json({ error: 'styleRequest required' });
    const result = await tryOn({ imageBase64, styleRequest, category, geometry });
    res.json(result);
  } catch (err) {
    console.error('[/tryon] error:', err);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`[mirror-backend] listening on :${PORT}`);
});
