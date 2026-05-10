## Mirrorly marketing assets — Mirror-tab before/after

The Mirror-tab pre-scan stack expects **two** JPEGs:

```
assets/marketing/before.jpg
assets/marketing/after.jpg
```

Drop the files here with those exact names. The Flutter side already
references them — no pubspec edits, no code edits. Replace, build,
done.

### Specs
- **Aspect ratio:** 4:5 portrait (e.g. 800 × 1000 px). The tile crops
  to 4:5, so anything else letterboxes.
- **Format:** JPEG, sRGB, ~80% quality. ~150 KB each is plenty.
- **Same face:** the BEFORE and AFTER must be the same person. Apple
  flags fake before/after marketing under guideline 4.2 / 5.0.
- **Lighting:** match before & after. Same angle, same light, same
  background. The only thing that should change is the transformation.

### Fallback
If either file is missing the tile renders a placeholder face icon —
the build still ships, the Mirror tab still loads. Drop the JPEGs
whenever they're ready.
