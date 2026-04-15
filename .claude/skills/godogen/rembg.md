# Background Removal

Background removal CLI using 302 AI API. Read when you're about to generate or process an asset that needs transparency.

Applies to: characters, props, icons, UI elements, animated sprite frames.
Does NOT apply to: textures, backgrounds, 3D model references (Tripo3D needs the solid white bg).

**CRITICAL: Never prompt for "transparent background" — the generator draws a checkerboard. Always use a solid color background, then remove it.**

## BG color strategy

Pick a prompt bg color that is (1) **distinct from the subject** so the mask separates cleanly, and (2) **close to the expected in-game environment** so residual fringe blends naturally.

Examples: forest game → `dark-green`; sky/water → `steel-blue`; dungeon → `dark-gray`; generic → `medium-gray`.

Avoid pure chromakey colors like `#00FF00` — they create unnatural green fringing.

The prompt must include a solid flat background color. Without it, the generator draws a detailed/noisy background that the mask cannot cleanly separate:
```
{name}, {description}. Centered on a solid {bg_color} background.
```

## CLI

### Single image

```bash
python ${CLAUDE_SKILL_DIR}/tools/rembg_matting.py \
  assets/img/car.png -o assets/img/car_nobg.png --preview
```

### Batch (video frames)

```bash
python ${CLAUDE_SKILL_DIR}/tools/rembg_matting.py \
  --batch frames_dir/ -o clean_dir/
```

- Uses 302 AI API for background removal
- Same flags apply to all frames

## QA verification

Always pass `--preview` when removing backgrounds. This generates a `_qa.png` file — the transparent result composited on a white background. Read the `_qa` image to check for remnants, fringing, or missing foreground. Delete the `_qa` file after inspection.

Claude's image reader cannot evaluate transparency directly — the preview is the only way to visually verify the result.

## Fixing results

If the result is not satisfactory:

1. **Background remnants** — regenerate the image with a more distinct background color
2. **Missing foreground** — regenerate the image with a more similar background color
3. **Fringing** — regenerate the image with a different background color

For best results, ensure the subject is centered and the background is uniform.