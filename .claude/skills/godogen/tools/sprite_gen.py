from __future__ import annotations

"""Sprite Sheet Generator CLI — generates NxN animation sprite sheets via 302.ai API.

Pipeline: LLM prompt rewrite (choreography) → nano-banana-2 sprite generation →
          background removal → optional grid splitting.

Subcommands:
  spritesheet  Generate a sprite sheet animation from a character description.

Output: JSON to stdout. Progress to stderr.
"""

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np
import requests
from PIL import Image

TOOLS_DIR = Path(__file__).parent

# Reuse budget tracking from asset_gen.py
sys.path.insert(0, str(TOOLS_DIR))
from asset_gen import BUDGET_FILE, check_budget, record_spend

# ---------------------------------------------------------------------------
# API configuration
# ---------------------------------------------------------------------------
API_KEY = os.environ.get("THREE_ZERO_TWO_AI_KEY", "")
if not API_KEY:
    raise ValueError("THREE_ZERO_TWO_AI_KEY environment variable not set")

REWRITE_ENDPOINT = "https://api.302ai.cn/v1/chat/completions"
REWRITE_MODEL = "gemini-3.1-flash-image-preview"

SPRITE_ENDPOINT = "https://api.302.ai/ws/api/v3/google/nano-banana-2/text-to-image"
SPRITE_EDIT_ENDPOINT = "https://api.302.ai/ws/api/v3/google/nano-banana-2/edit"

SPRITE_COST = 5  # cents per sprite sheet generation

NUM_WORDS = {2: "two", 3: "three", 4: "four", 5: "five", 6: "six"}

ANIMATION_DESCRIPTIONS = {
    "auto": "a natural idle stance with subtle breathing movement",
    "idle": "a breathing idle loop, weight gently shifting between feet",
    "walk": "a walk cycle, left foot forward then right foot forward, arms swinging opposite to legs, clear contact-pass-up-pass phases",
    "run": "a running cycle, strong forward lean, legs driving back, arms pumping, visible airtime phase between strides",
    "attack": "a combo attack: wind-up with weapon raised, powerful forward slash, follow-through strike, recovery back to stance",
    "cast": "a magic cast: energy gathering in hands, arms raised overhead, burst of power released outward, cooldown and hands lowered",
    "jump": "a jump sequence: crouch and coil, explosive upward launch, peak of arc with arms spread, graceful landing with knees bent",
    "dance": "a rhythmic dance loop with expressive body movements and flowing poses",
    "death": "a death sequence: sudden impact, stumble backward, collapse to knees, fall forward to ground",
    "dodge": "a dodge roll: lean and duck, rapid sideways roll, quick recovery to standing ready stance",
}


# ---------------------------------------------------------------------------
# LLM prompt rewrite
# ---------------------------------------------------------------------------
def build_rewrite_system_prompt(grid_size: int) -> str:
    w = NUM_WORDS.get(grid_size, "four")
    return "\n".join([
        "You are an animation director and character designer for a sprite sheet pipeline.",
        "Given a character concept, you MUST return exactly two sections, nothing else:",
        "",
        "CHARACTER: A vivid description of the character's appearance — body type, armor, weapons, colors, silhouette, art style. Be extremely specific and visual.",
        "",
        f"CHOREOGRAPHY: A {w}-beat continuous animation loop that showcases this specific character's personality and abilities. Each beat is one row of the sheet. The last beat must transition seamlessly back into the first.",
        "For each beat, describe the body position, weight distribution, limb placement, and motion arc in one sentence.",
        "The choreography must feel natural and unique to THIS character — a mage animates differently than a knight, a dancer differently than a berserker.",
        "",
        "RULES:",
        "- Never use numbers or digits anywhere.",
        "- Never mention grids, pixels, frames, cells, or image generation.",
        "- Never mention sprite sheets or technical terms.",
        "- Write as if directing a real actor through a motion capture session.",
        f"- The {w} beats must form one fluid, looping performance.",
        "- For locomotion (walk/run): strictly alternate left and right legs in each beat.",
        "  Describe exact limb positions — which leg is forward, which is pushing off,",
        "  which arm is swinging forward. Every beat must show a distinctly different leg configuration.",
    ])


def build_sprite_prompt(base_prompt: str, grid_size: int = 4) -> str:
    w = NUM_WORDS.get(grid_size, "four")
    return "\n".join([
        "STRICT TECHNICAL REQUIREMENTS FOR THIS IMAGE:",
        "",
        f"FORMAT: A single image containing a {w}-by-{w} grid of equally sized cells.",
        "Every cell must be the exact same dimensions, perfectly aligned, with no gaps or overlap.",
        "",
        "FORBIDDEN: Absolutely no text, no numbers, no letters, no digits, no labels,",
        "no watermarks, no signatures, no UI elements anywhere in the image. The image must",
        "contain ONLY the character illustrations in the grid cells and nothing else.",
        "",
        "CONSISTENCY: The exact same single character must appear in every cell.",
        "Same proportions, same art style, same level of detail, same camera angle throughout.",
        "Isometric three-quarter view. Full body visible head to toe in every cell.",
        "Strong clean silhouette against a plain solid flat-color background.",
        "",
        "ANIMATION FLOW: The cells read left-to-right, top-to-bottom, like reading a page.",
        "This is one continuous motion sequence. Each cell shows the next moment in the movement.",
        "The transition between the last cell of one row and the first cell of the next row",
        "must be just as smooth as transitions within a row — no jumps, no resets.",
        f"Each row contains {w} phases of the motion. The very last cell loops back seamlessly",
        "to the very first cell.",
        "",
        "MOTION QUALITY: Show real weight and physics. Bodies shift weight between feet.",
        "Arms counterbalance legs. Torsos rotate into actions. Follow-through on every movement.",
        "No stiff poses — every cell must feel like a freeze-frame of fluid motion.",
        "For locomotion (walk/run): strictly alternate left and right legs — one leg extends forward",
        "while the other pushes behind. Each frame must show a clearly different leg position.",
        "Never repeat the same pose twice in a row.",
        "",
        "CHARACTER AND ANIMATION DIRECTION:",
        base_prompt,
    ])


def rewrite_prompt(character_desc: str, animation_type: str, grid_size: int) -> str:
    """Use LLM to rewrite character description with choreography direction."""
    anim_desc = ANIMATION_DESCRIPTIONS.get(animation_type, ANIMATION_DESCRIPTIONS["auto"])
    user_msg = (
        f"Design the character and choreograph a {NUM_WORDS.get(grid_size, 'four')}-beat "
        f"animation loop for: {character_desc}\n\nAnimation type: {anim_desc}"
    )

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": REWRITE_MODEL,
        "messages": [
            {"role": "system", "content": build_rewrite_system_prompt(grid_size)},
            {"role": "user", "content": user_msg},
        ],
        "max_tokens": 1024,
        "temperature": 0.7,
    }

    print("Rewriting prompt with LLM...", file=sys.stderr)
    resp = None
    for attempt in range(3):
        try:
            resp = requests.post(REWRITE_ENDPOINT, headers=headers, json=payload, timeout=120)
            break
        except requests.exceptions.Timeout:
            print(f"LLM rewrite timeout (attempt {attempt+1}/3), retrying...", file=sys.stderr)
        except Exception as e:
            print(f"LLM rewrite error: {e} (attempt {attempt+1}/3), retrying...", file=sys.stderr)

    if resp is None or resp.status_code != 200:
        print("LLM rewrite failed, using raw prompt", file=sys.stderr)
        return build_sprite_prompt(f"{character_desc}. {anim_desc}", grid_size)

    data = resp.json()
    rewritten = ""
    for choice in data.get("choices", []):
        content = choice.get("message", {}).get("content", "")
        if content:
            rewritten = content.strip()

    # Strip code fences if present
    if rewritten.startswith("```"):
        rewritten = rewritten.split("\n", 1)[1] if "\n" in rewritten else rewritten[3:]
        if rewritten.endswith("```"):
            rewritten = rewritten[:-3]
        rewritten = rewritten.strip()

    if not rewritten:
        print("LLM returned empty, using raw prompt", file=sys.stderr)
        return build_sprite_prompt(f"{character_desc}. {anim_desc}", grid_size)

    print(f"Rewritten prompt ({len(rewritten)} chars)", file=sys.stderr)
    return build_sprite_prompt(rewritten, grid_size)


# ---------------------------------------------------------------------------
# Sprite sheet generation (queued nano-banana-2)
# ---------------------------------------------------------------------------
def _request_json(url, method, payload, timeout=240):
    """JSON request with timeout."""
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    try:
        resp = requests.request(method, url, headers=headers,
                                json=payload if method == "POST" else None,
                                timeout=timeout)
        text = resp.text
        try:
            data = json.loads(text) if text else {}
        except json.JSONDecodeError:
            data = {"raw": text}
        return resp.ok, resp.status_code, data
    except requests.exceptions.Timeout:
        return False, 408, {"error": "Request timeout"}
    except Exception as e:
        return False, 500, {"error": str(e)}


def generate_sprite_sheet(prompt: str, grid_size: int, resolution: str = "2k",
                          reference_image: Optional[Path] = None,
                          output: Path = None) -> bool:
    """Generate sprite sheet via nano-banana-2 queued endpoint."""
    endpoint = SPRITE_EDIT_ENDPOINT if reference_image else SPRITE_ENDPOINT

    payload = {
        "prompt": prompt,
        "aspect_ratio": "1:1",
        "resolution": resolution.lower(),
        "num_images": 1,
        "output_format": "png",
        "safety_tolerance": 2,
        "expand_prompt": True,
    }

    # Attach reference image for edit mode
    if reference_image and reference_image.exists():
        with open(reference_image, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        payload["image"] = f"data:image/png;base64,{b64}"

    # Step 1: Submit request
    print(f"Submitting sprite sheet to {endpoint}...", file=sys.stderr)
    ok, status, data = _request_json(endpoint, "POST", payload)

    if not ok:
        print(f"Submit failed: {status} {data}", file=sys.stderr)
        return False

    request_id = data.get("data", {}).get("id", "")
    status_url = data.get("data", {}).get("urls", {}).get("get", "")

    if not request_id or not status_url:
        print(f"No request_id or status_url in response: {data}", file=sys.stderr)
        return False

    print(f"Request submitted: id={request_id}", file=sys.stderr)

    # Step 2: Poll for completion
    timeout_at = time.time() + 600  # 10 minutes
    poll_interval = 5

    while time.time() < timeout_at:
        elapsed = int(time.time() - timeout_at + 600)
        print(f"  Polling status ({elapsed}s elapsed)...", file=sys.stderr)

        ok, status, data = _request_json(status_url, "GET", {}, timeout=30)
        if not ok:
            print(f"  Status check failed: {status}", file=sys.stderr)
            time.sleep(poll_interval)
            continue

        state = data.get("data", {}).get("status", "")
        if state.upper() == "COMPLETED":
            break
        if state.upper() == "FAILED":
            print(f"  Generation failed: {data}", file=sys.stderr)
            return False

        time.sleep(poll_interval)
    else:
        print("  Timed out after 10 minutes", file=sys.stderr)
        return False

    # Step 3: Extract image URL and download
    outputs = data.get("data", {}).get("outputs", [])
    if not outputs:
        print(f"No outputs in result: {data}", file=sys.stderr)
        return False

    image_url = outputs[0]
    print(f"  Image URL: {image_url}", file=sys.stderr)

    print("  Downloading sprite sheet...", file=sys.stderr)
    try:
        img_resp = requests.get(image_url, timeout=120, verify=False)
        img_resp.raise_for_status()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(img_resp.content)
        print(f"  Saved: {output}", file=sys.stderr)
        record_spend(SPRITE_COST, "302-ai")
        return True
    except Exception as e:
        print(f"  Download failed: {e}", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# Background removal
# ---------------------------------------------------------------------------
def remove_background(input_path: Path, output_path: Path) -> bool:
    """Remove background using 302 AI recraft API."""
    from rembg_matting import remove_background_api

    print("Removing background...", file=sys.stderr)
    if remove_background_api(input_path, output_path, preview=False):
        # Binarize alpha to remove halo
        _binarize_alpha(output_path)
        return True
    return False


def _binarize_alpha(image_path: Path):
    """Threshold alpha: < 200 → 0, >= 200 → 255. Removes semi-transparent halo."""
    img = Image.open(image_path).convert("RGBA")
    arr = np.array(img)
    alpha = arr[:, :, 3]
    arr[alpha < 200, 3] = 0
    arr[alpha >= 200, 3] = 255
    Image.fromarray(arr).save(image_path)
    print(f"  Alpha binarized: {image_path}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Grid splitting
# ---------------------------------------------------------------------------
def split_sprite_sheet(image_path: Path, grid_size: int) -> str:
    """Split sprite sheet into individual frames. Returns frames_dir path string."""
    from grid_slice import slice_grid

    stem = image_path.stem
    frames_dir = image_path.parent / f"{stem}_frames"
    grid_str = f"{grid_size}x{grid_size}"
    slice_grid(image_path, frames_dir, grid_size, grid_size, None)
    return str(frames_dir)


# ---------------------------------------------------------------------------
# Main command
# ---------------------------------------------------------------------------
def cmd_spritesheet(args):
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    check_budget(SPRITE_COST)

    # Step 1: LLM rewrite
    sprite_prompt = rewrite_prompt(args.prompt, args.animation, args.grid)

    # Step 2: Generate sprite sheet
    ref_image = Path(args.image) if args.image else None
    if not generate_sprite_sheet(sprite_prompt, args.grid, args.size, ref_image, output):
        print(json.dumps({"ok": False, "error": "Sprite sheet generation failed"}))
        sys.exit(1)

    # Step 3: Background removal
    if args.rembg:
        if not remove_background(output, output):
            print(json.dumps({"ok": False, "error": "Background removal failed"}))
            sys.exit(1)

    # Step 4: Grid splitting
    frames_dir = None
    if args.split:
        frames_dir = split_sprite_sheet(output, args.grid)

    result = {
        "ok": True,
        "path": str(output),
        "cost_cents": SPRITE_COST,
        "grid": args.grid,
        "animation": args.animation,
        "frames": args.grid * args.grid,
    }
    if frames_dir:
        result["frames_dir"] = frames_dir

    print(json.dumps(result))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser(description="Generate sprite sheet animations")
    sub = p.add_subparsers(dest="command", required=True)

    # spritesheet subcommand
    sp = sub.add_parser("spritesheet", help="Generate NxN sprite sheet animation")
    sp.add_argument("--prompt", required=True, help="Character description")
    sp.add_argument("--animation", default="auto",
                    choices=["auto", "idle", "walk", "run", "attack", "cast",
                             "jump", "dance", "death", "dodge"],
                    help="Animation type. Default: auto")
    sp.add_argument("--grid", type=int, default=4, choices=[2, 3, 4, 5, 6],
                    help="Grid size N (NxN frames). Default: 4")
    sp.add_argument("--size", default="2k", help="Resolution. Default: 2k")
    sp.add_argument("--rembg", action="store_true", help="Remove background")
    sp.add_argument("--split", action="store_true", help="Split into individual frames")
    sp.add_argument("--image", default=None, help="Reference image for edit mode")
    sp.add_argument("-o", "--output", required=True, help="Output path for sprite sheet")
    sp.set_defaults(func=cmd_spritesheet)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
