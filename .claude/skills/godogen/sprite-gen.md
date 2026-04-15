# Sprite Sheet Generation

Generate NxN animation sprite sheets for 2D game characters via 302.ai nano-banana-2 API.

## When to use

- Character locomotion: run, walk, idle cycles
- Combat: attack, cast, dodge animations
- Game events: jump, death sequences
- **Preferred over video-based animation** for most 2D games — produces consistent frames in a single call

## Animation Types

| Type | Description | Loop? | Typical grid |
|------|-------------|-------|-------------|
| `idle` | Breathing, subtle weight shift | Yes | 4x4 |
| `walk` | Walk cycle, alternating legs | Yes | 4x4 |
| `run` | Running cycle with airtime | Yes | 4x4 |
| `attack` | Weapon attack combo | No | 4x4 |
| `cast` | Magic spell cast sequence | No | 4x4 |
| `jump` | Crouch → launch → air → land | No | 3x3 |
| `dance` | Rhythmic body movement | Yes | 4x4 |
| `death` | Impact → collapse → fall | No | 3x3 |
| `dodge` | Lean → roll → recover | No | 3x3 |
| `auto` | LLM decides based on character | varies | 4x4 |

## CLI

```bash
python3 ${CLAUDE_SKILL_DIR}/tools/sprite_gen.py spritesheet \
  --prompt "character description" \
  --animation run \
  --grid 4 \
  --rembg --split \
  -o assets/img/char_run.png
```

| Flag | Default | Description |
|------|---------|-------------|
| `--prompt` | required | Character description (style, colors, proportions) |
| `--animation` | `auto` | Animation type |
| `--grid` | `4` | N (NxN = N² frames). Options: 2, 3, 4 |
| `--size` | `2k` | Resolution (must be 2k for sprite sheets) |
| `--rembg` | off | Remove background + alpha binarization |
| `--split` | off | Split into individual frames |
| `--image` | none | Reference image for edit-based generation |
| `-o` | required | Output path for sprite sheet PNG |

## Cost

| Operation | Cost |
|-----------|------|
| Sprite sheet generation | ~5¢ per animation |
| + Background removal | ~6¢ |

Budget is tracked via `assets/budget.json` (shared with asset_gen.py).

## Pipeline

1. **LLM rewrite** — Gemini Flash rewrites character description with animation choreography
2. **Sprite generation** — nano-banana-2 generates NxN grid (5-6 min)
3. **Background removal** — 302.ai recraft API + alpha binarization (if `--rembg`)
4. **Grid splitting** — Individual frame PNGs (if `--split`)

## Prompting Guidelines

### Character consistency
Use the exact same character description across all animations for a character. Include:
- Physical features (body type, colors, distinctive traits)
- Clothing/equipment (armor, weapons, accessories)
- Art style (pixel art, chibi, flat colors, bold outlines)

Example consistent prompt:
```
Sun Wukong, monkey king, golden chainmail armor, red sash, holding golden staff,
bold black outlines, flat colors, chibi proportions
```

### BG color
Sprite sheets use a solid flat background internally (handled by the system prompt). Don't add BG color to your `--prompt` — it's automatic.

### Multiple animations
Generate each animation as a separate call. For better consistency, pass the first generated sprite sheet as `--image` reference for subsequent animations.

```bash
# First animation
python3 sprite_gen.py spritesheet --prompt "..." --animation idle --grid 4 --rembg -o assets/img/char_idle.png

# Subsequent animations with reference
python3 sprite_gen.py spritesheet --prompt "..." --animation run --grid 4 --rembg --image assets/img/char_idle.png -o assets/img/char_run.png
```

## Godot Integration

### Option A: Sprite2D with hframes/vframes (single animation)

Simplest approach — works for characters with only one animation.

```gdscript
var sprite = Sprite2D.new()
sprite.texture = load("res://assets/img/char_run.png")
sprite.hframes = 4
sprite.vframes = 4
# Animate by incrementing sprite.frame in _process()
```

### Option B: AnimatedSprite2D with SpriteFrames (multiple animations, recommended)

Supports multiple animations per character (run, idle, attack, etc.).

**IMPORTANT:** For generated sprite sheets (no `.import` file), load textures at runtime using `Image.load_from_file()` — see "Runtime Loading" section below. Do NOT use `load()` in scene builders for generated assets.

```gdscript
# In runtime _ready():
var image := Image.load_from_file("res://assets/img/char_run.png")
var tex := ImageTexture.create_from_image(image)

var sf = SpriteFrames.new()
var grid := 4
var fw: float = float(tex.get_width()) / float(grid)
var fh: float = float(tex.get_height()) / float(grid)

sf.add_animation("run")
sf.set_animation_speed("run", 12.0)
sf.set_animation_loop("run", true)  # NOT set_loop()
for i in range(grid * grid):
    var at := AtlasTexture.new()
    at.atlas = tex
    var col := i % grid
    var row := i / grid
    at.region = Rect2(float(col) * fw, float(row) * fh, fw, fh)
    sf.add_frame("run", at)

_sprite.sprite_frames = sf
_sprite.play("run")
```

### Frame timing

- Grid 3x3 (9 frames): speed 8-10 FPS
- Grid 4x4 (16 frames): speed 10-14 FPS
- Looping animations (walk/run/idle): `sf.set_animation_loop("anim", true)` — **NOT `set_loop()`**, that doesn't exist
- One-shot animations (attack/death): `sf.set_animation_loop("anim", false)`, listen to `animation_finished` signal

## Runtime Loading (Critical)

Sprite sheets are generated AFTER the project exists, so they have no `.import` files. **`load()` returns null without `.import` files** in normal game mode. Use `Image.load_from_file()` instead:

```gdscript
var image := Image.load_from_file("res://assets/img/char_run.png")
var tex := ImageTexture.create_from_image(image)
# Now use tex with AnimatedSprite2D / SpriteFrames
```

This works in both headless (scene builder) and normal (game) mode.

## Scaling

Generated sprite sheets are large (2048px). Calculate scale based on desired display size:

```gdscript
var grid := 4
var fh: float = float(tex.get_height()) / float(grid)  # frame height (e.g., 512)
var display_h := 80.0  # how tall the character should appear
var scale_factor: float = display_h / fh  # e.g., 0.156
_sprite.scale = Vector2(scale_factor, scale_factor)
```

Store `_base_scale` to restore after effects (slide squish, etc.).

## Scene Builder vs Runtime

Sprite sheet setup CANNOT happen in scene builders (`--headless --script`). The texture loading and SpriteFrames construction must happen in the character's `_ready()` method:

- **Scene builder:** create only `AnimatedSprite2D` node (empty, no texture)
- **Runtime `_ready()`:** load image, build SpriteFrames with AtlasTexture regions, set scale, play animation

```gdscript
# Scene builder — just the node
var anim_sprite := AnimatedSprite2D.new()
anim_sprite.name = "AnimatedSprite2D"
root.add_child(anim_sprite)
```

## Integer Truncation Trap

GDScript integer division truncates. Without `float()` casts, `Rect2` regions will be wrong:

```gdscript
# WRONG — integer division truncates, frames crop incorrectly
var fw = tex.get_width() / 4
var col = i % 4
at.region = Rect2(col * fw, row * fh, fw, fh)

# CORRECT — float division preserves precision
var fw: float = float(tex.get_width()) / float(grid)
var col := i % grid
at.region = Rect2(float(col) * fw, float(row) * fh, fw, fh)
```
