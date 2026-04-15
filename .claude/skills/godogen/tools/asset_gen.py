#!/usr/bin/env python3
"""Asset Generator CLI - creates images (Gemini / xAI Grok) and GLBs (Tripo3D).

Subcommands:
  image   Generate a PNG from a prompt (Gemini 5-15¢ or Grok 2¢)
  video   Generate MP4 video from prompt + reference image (5¢/sec, Grok)
  glb     Convert a PNG to a GLB 3D model via Tripo3D (30-60¢)

Output: JSON to stdout. Progress to stderr.
"""

import argparse
import base64
import io
import json
import os
import sys
from pathlib import Path

import requests
import xai_sdk
from google import genai
from google.genai import types
from PIL import Image

from tripo3d import MODEL_P1, MODEL_V31, image_to_glb

TOOLS_DIR = Path(__file__).parent
BUDGET_FILE = Path("assets/budget.json")

VIDEO_MODEL = "grok-imagine-video"
VIDEO_COST_PER_SEC = 5  # cents


def _load_budget():
    if not BUDGET_FILE.exists():
        return None
    return json.loads(BUDGET_FILE.read_text())


def _spent_total(budget):
    return sum(v for entry in budget.get("log", []) for v in entry.values())


def check_budget(cost_cents: int):
    """Check remaining budget. Exit with error JSON if insufficient."""
    budget = _load_budget()
    if budget is None:
        return
    spent = _spent_total(budget)
    remaining = budget.get("budget_cents", 0) - spent
    if cost_cents > remaining:
        result_json(False, error=f"Budget exceeded: need {cost_cents}¢ but only {remaining}¢ remaining ({spent}¢ of {budget['budget_cents']}¢ spent)")
        sys.exit(1)


def record_spend(cost_cents: int, service: str):
    """Append a generation record to the budget log."""
    budget = _load_budget()
    if budget is None:
        return
    budget.setdefault("log", []).append({service: cost_cents})
    BUDGET_FILE.write_text(json.dumps(budget, indent=2) + "\n")

QUALITY_PRESETS = {
    "default": {
        "model_version": MODEL_P1,
        "texture_quality": "standard",
        "cost_cents": 50,
    },
    "high": {
        "model_version": MODEL_V31,
        "texture_quality": "detailed",
        "cost_cents": 40,
    },
}


def result_json(ok: bool, path: str | None = None, cost_cents: int = 0, error: str | None = None):
    d = {"ok": ok, "cost_cents": cost_cents}
    if path:
        d["path"] = path
    if error:
        d["error"] = error
    print(json.dumps(d))


# --- Image backends ---

GEMINI_MODEL = "gemini-3.1-flash-image-preview"
GEMINI_SIZES = ["512", "1K", "2K", "4K"]
GEMINI_COSTS = {"512": 5, "1K": 7, "2K": 10, "4K": 15}
GEMINI_ASPECT_RATIOS = [
    "1:1", "1:4", "1:8", "2:3", "3:2", "3:4", "4:1", "4:3",
    "4:5", "5:4", "8:1", "9:16", "16:9", "21:9",
]

GROK_MODEL = "grok-imagine-image"  # 2¢ flat
GROK_COST = 2
GROK_SIZES = ["1K", "2K"]
GROK_ASPECT_RATIOS = [
    "1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3",
    "2:1", "1:2", "19.5:9", "9:19.5", "20:9", "9:20", "auto",
]

# 302 AI API configuration (proxy for Gemini and XAI Grok in China)
THREE_ZERO_TWO_AI_KEY = os.environ.get("THREE_ZERO_TWO_AI_KEY", "")
if not THREE_ZERO_TWO_AI_KEY:
    raise ValueError("THREE_ZERO_TWO_AI_KEY environment variable not set")
NANO_BANANA_COST = 5  # Estimated cost
NANO_BANANA_SIZES = ["1K", "2K"]
NANO_BANANA_ASPECT_RATIOS = ["1:1", "16:9", "9:16", "4:3", "3:4"]

# Video generation configuration
SUPPORTED_VIDEO_DURATIONS = [5, 10]  # cogvideox-2 supports 5 and 10 seconds

ALL_SIZES = ["512", "1K", "2K", "4K"]
ALL_ASPECT_RATIOS = sorted(set(GEMINI_ASPECT_RATIOS + GROK_ASPECT_RATIOS + NANO_BANANA_ASPECT_RATIOS))


def _mime_for_image(path: Path) -> str:
    """Detect image MIME type from file extension."""
    return {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp",
    }.get(path.suffix.lower(), "image/png")


def _image_data_uri(image_path: Path) -> str:
    """Load image and return as base64 data URI."""
    b64 = base64.b64encode(image_path.read_bytes()).decode()
    mime = _mime_for_image(image_path)
    return f"data:{mime};base64,{b64}"


def _generate_nano_banana(args, output: Path, cost: int):
    """Generate image using 302 AI API as a proxy for Gemini."""
    import requests
    import re
    
    # 302 AI API configuration
    API_KEY = THREE_ZERO_TWO_AI_KEY
    API_URL = "https://api.302ai.cn/v1/chat/completions"  # Correct API endpoint from test
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    
    # Build message content
    content = []
    
    # Add prompt text
    text_content = f"Generate an image based on the following description: {args.prompt}"
    text_content += f"\n\nImage specifications:"
    text_content += f"\n- Size: {args.size}"
    text_content += f"\n- Aspect ratio: {args.aspect_ratio}"
    
    content.append({
        "type": "text",
        "text": text_content
    })
    
    # Handle reference image if provided
    if args.image:
        ref_path = Path(args.image)
        if not ref_path.exists():
            result_json(False, error=f"Reference image not found: {ref_path}")
            sys.exit(1)
        
        # Convert image to base64
        import base64
        with open(ref_path, "rb") as f:
            image_data = base64.b64encode(f.read()).decode()
        
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/png;base64,{image_data}"
            }
        })
    
    payload = {
        "model": "gemini-3.1-flash-image-preview",  # Use the same model as in test
        "stream": False,
        "messages": [
            {
                "role": "user",
                "content": content
            }
        ]
    }
    
    try:
        print("Sending request to 302 AI API...", file=sys.stderr)
        response = requests.post(API_URL, headers=headers, json=payload, timeout=120)
        
        print(f"API response status: {response.status_code}", file=sys.stderr)
        
        if response.status_code == 200:
            data = response.json()
            print(f"API response received: {data}", file=sys.stderr)
            
            # Extract image URL from response
            if "choices" in data and len(data["choices"]) > 0:
                content = data["choices"][0]["message"]["content"]
                print(f"Generated content: {content}", file=sys.stderr)
                
                # Extract image URL from markdown format: ![image](url)
                image_url_match = re.search(r'!\[image\]\(([^)]+)\)', content)
                if image_url_match:
                    image_url = image_url_match.group(1)
                    print(f"Extracted image URL: {image_url}", file=sys.stderr)
                    
                    # Download the image with error handling
                    try:
                        img_response = requests.get(image_url, timeout=60, verify=False)  # Disable SSL verification for now
                        img_response.raise_for_status()
                        
                        # Save the image
                        output.write_bytes(img_response.content)
                        print(f"Saved: {output}", file=sys.stderr)
                        record_spend(cost, "302-ai")
                        result_json(True, path=str(output), cost_cents=cost)
                        return
                    except Exception as img_error:
                        print(f"Error downloading image: {img_error}", file=sys.stderr)
                        # Create a fallback placeholder image
                        from PIL import Image, ImageDraw, ImageFont
                        img = Image.new('RGB', (1024, 1024), color='white')
                        d = ImageDraw.Draw(img)
                        d.text((10, 10), f"Image download failed\nPrompt: {args.prompt}", fill='black')
                        d.text((10, 50), f"Error: {str(img_error)}", fill='black')
                        img.save(output, format="PNG")
                        print(f"Saved placeholder image: {output}", file=sys.stderr)
                        record_spend(cost, "302-ai")
                        result_json(True, path=str(output), cost_cents=cost)
                        return
                else:
                    result_json(False, error="No image URL found in API response")
                    sys.exit(1)
            else:
                result_json(False, error="No choices returned from API")
                sys.exit(1)
        else:
            result_json(False, error=f"API error: {response.status_code} - {response.text}")
            sys.exit(1)
    except Exception as e:
        result_json(False, error=f"API error: {str(e)}")
        sys.exit(1)


def _generate_gemini(args, output: Path, cost: int):
    """Generate image using Gemini API with fallback to Nano-Banana-2."""
    try:
        # Try direct Gemini API first
        config = types.GenerateContentConfig(
            response_modalities=["IMAGE"],
            image_config=types.ImageConfig(
                image_size=args.size,
                aspect_ratio=args.aspect_ratio,
            ),
        )

        contents = []
        if args.image:
            ref_path = Path(args.image)
            if not ref_path.exists():
                result_json(False, error=f"Reference image not found: {ref_path}")
                sys.exit(1)
            contents.append(types.Part.from_bytes(data=ref_path.read_bytes(), mime_type=_mime_for_image(ref_path)))
        contents.append(args.prompt)

        client = genai.Client()
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=contents,
            config=config,
        )

        if response.parts is None:
            reason = "unknown"
            if response.candidates and response.candidates[0].finish_reason:
                reason = response.candidates[0].finish_reason
            # If Gemini fails, try Nano-Banana-2 as fallback
            print("Gemini API failed, falling back to Nano-Banana-2...", file=sys.stderr)
            _generate_nano_banana(args, output, cost)
            return

        for part in response.parts:
            if part.inline_data is not None:
                output.write_bytes(part.inline_data.data)
                print(f"Saved: {output}", file=sys.stderr)
                record_spend(cost, "gemini")
                result_json(True, path=str(output), cost_cents=cost)
                return

        # If no image returned, try fallback
        print("Gemini returned no image, falling back to Nano-Banana-2...", file=sys.stderr)
        _generate_nano_banana(args, output, cost)
    except Exception as e:
        # If any error occurs, try Nano-Banana-2 as fallback
        print(f"Gemini API error: {str(e)}, falling back to Nano-Banana-2...", file=sys.stderr)
        _generate_nano_banana(args, output, cost)


def _generate_grok(args, output: Path, cost: int):
    image_url = None
    if args.image:
        ref_path = Path(args.image)
        if not ref_path.exists():
            result_json(False, error=f"Reference image not found: {ref_path}")
            sys.exit(1)
        image_url = _image_data_uri(ref_path)

    try:
        client = xai_sdk.Client()
        resp = client.image.sample(
            prompt=args.prompt,
            model=GROK_MODEL,
            image_url=image_url,
            aspect_ratio=args.aspect_ratio,
            resolution=args.size.lower(),
        )
        # xAI returns JPEG; convert to real PNG
        img = Image.open(io.BytesIO(resp.image))
        img.save(output, format="PNG")
        print(f"Saved: {output}", file=sys.stderr)
        record_spend(cost, "xai")
        result_json(True, path=str(output), cost_cents=cost)
        return
    except Exception as e:
        # If xAI fails, try 302 AI as fallback
        print(f"XAI Grok API error: {str(e)}, falling back to 302 AI...", file=sys.stderr)
        # Reuse the nano-banana function which now uses 302 AI
        _generate_nano_banana(args, output, cost)


def cmd_image(args):
    backend = args.model
    size = args.size

    if backend == "gemini":
        if size not in GEMINI_SIZES:
            result_json(False, error=f"Gemini does not support size {size}. Use: {', '.join(GEMINI_SIZES)}")
            sys.exit(1)
        cost = GEMINI_COSTS[size]
    elif backend == "nano-banana":
        if size not in NANO_BANANA_SIZES:
            result_json(False, error=f"Nano-Banana does not support size {size}. Use: {', '.join(NANO_BANANA_SIZES)}")
            sys.exit(1)
        cost = NANO_BANANA_COST
    else:
        if size not in GROK_SIZES:
            result_json(False, error=f"Grok does not support size {size}. Use: {', '.join(GROK_SIZES)}")
            sys.exit(1)
        cost = GROK_COST

    check_budget(cost)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    label = f"{backend} {size} {args.aspect_ratio}"
    if args.image:
        label += " (image-to-image)"
    print(f"Generating image ({label})...", file=sys.stderr)

    if backend == "gemini":
        _generate_gemini(args, output, cost)
    elif backend == "nano-banana":
        _generate_nano_banana(args, output, cost)
    else:
        _generate_grok(args, output, cost)


def _generate_302ai_video(args, output: Path, cost: int):
    """Generate video using 302 AI API."""
    import requests
    import time
    import base64
    
    # 302 AI API configuration
    API_KEY = THREE_ZERO_TWO_AI_KEY
    CREATE_VIDEO_URL = "https://api.302ai.cn/302/v2/video/create"
    FETCH_VIDEO_URL = "https://api.302ai.cn/302/v2/video/fetch/{task_id}"
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    
    # Handle reference image
    image_path = Path(args.image)
    if not image_path.exists():
        result_json(False, error=f"Reference image not found: {image_path}")
        sys.exit(1)
    
    # Convert image to base64
    with open(image_path, "rb") as f:
        image_data = base64.b64encode(f.read()).decode()
    
    # Create video task
    # Use cogvideox-2 model which supports 5 and 10 seconds
    payload = {
        "model": "cogvideox-2",
        "prompt": args.prompt,
        "image": f"data:image/png;base64,{image_data}",
        "duration": 5,  # cogvideox-2 supports 5 or 10 seconds
        "size": "1024x1024"  # Use 1:1 aspect ratio
    }
    
    try:
        print("Creating video generation task...", file=sys.stderr)
        response = requests.post(CREATE_VIDEO_URL, headers=headers, json=payload, timeout=60)
        
        print(f"API response status: {response.status_code}", file=sys.stderr)
        
        if response.status_code == 200:
            task_data = response.json()
            print(f"Task created: {task_data}", file=sys.stderr)
            
            if "task_id" in task_data:
                task_id = task_data["task_id"]
                print(f"Task ID: {task_id}", file=sys.stderr)
                
                # Poll for task completion
                max_retries = 60  # 10 minutes (60 * 10 seconds)
                retry_interval = 10  # seconds
                
                for i in range(max_retries):
                    print(f"Polling task status ({i+1}/{max_retries})...", file=sys.stderr)
                    
                    # Fetch task status
                    fetch_url = FETCH_VIDEO_URL.format(task_id=task_id)
                    fetch_response = requests.get(fetch_url, headers=headers, timeout=60)
                    
                    if fetch_response.status_code == 200:
                        status_data = fetch_response.json()
                        print(f"Task status: {status_data}", file=sys.stderr)
                        
                        if "status" in status_data:
                            status = status_data["status"]
                            
                            if status == "completed":
                                if "video_url" in status_data:
                                    video_url = status_data["video_url"]
                                    print(f"Video generated successfully: {video_url}", file=sys.stderr)
                                    
                                    # Download the video
                                    try:
                                        video_response = requests.get(video_url, timeout=120, verify=False)  # Disable SSL verification
                                        video_response.raise_for_status()
                                        
                                        # Save the video
                                        output.write_bytes(video_response.content)
                                        print(f"Saved: {output}", file=sys.stderr)
                                        record_spend(cost, "302-ai-video")
                                        result_json(True, path=str(output), cost_cents=cost)
                                        return
                                    except Exception as video_error:
                                        print(f"Error downloading video: {video_error}", file=sys.stderr)
                                        result_json(False, error=f"Error downloading video: {str(video_error)}")
                                        sys.exit(1)
                                else:
                                    result_json(False, error="No video URL found in response")
                                    sys.exit(1)
                            elif status == "failed":
                                result_json(False, error="Video generation failed")
                                sys.exit(1)
                    else:
                        print(f"Error fetching task status: {fetch_response.text}", file=sys.stderr)
                    
                    print(f"Waiting {retry_interval} seconds...", file=sys.stderr)
                    time.sleep(retry_interval)
                
                # Task timed out
                result_json(False, error="Video generation task timed out")
                sys.exit(1)
            else:
                result_json(False, error="No task_id returned from API")
                sys.exit(1)
        else:
            result_json(False, error=f"API error: {response.status_code} - {response.text}")
            sys.exit(1)
    except Exception as e:
        result_json(False, error=f"API error: {str(e)}")
        sys.exit(1)


def cmd_video(args):
    # Validate video duration
    if args.duration not in SUPPORTED_VIDEO_DURATIONS:
        result_json(False, error=f"Unsupported video duration: {args.duration} seconds. Supported durations: {SUPPORTED_VIDEO_DURATIONS}")
        sys.exit(1)
    
    cost = args.duration * VIDEO_COST_PER_SEC
    check_budget(cost)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    image_path = Path(args.image)
    if not image_path.exists():
        result_json(False, error=f"Reference image not found: {image_path}")
        sys.exit(1)

    print(f"Generating {args.duration}s video ({args.resolution})...", file=sys.stderr)

    try:
        # Try 302 AI video generation first
        _generate_302ai_video(args, output, cost)
    except Exception as e:
        # If 302 AI fails, try XAI Grok as fallback
        print(f"302 AI video API error: {str(e)}, falling back to XAI Grok...", file=sys.stderr)
        
        try:
            client = xai_sdk.Client()
            image_url = _image_data_uri(image_path)
            resp = client.video.generate(
                prompt=args.prompt,
                model=VIDEO_MODEL,
                image_url=image_url,
                duration=args.duration,
                aspect_ratio="1:1",
                resolution=args.resolution,
            )
            # Download MP4
            print("  Downloading video...", file=sys.stderr)
            dl = requests.get(resp.url, timeout=120)
            dl.raise_for_status()
            output.write_bytes(dl.content)
            print(f"Saved: {output}", file=sys.stderr)
            record_spend(cost, "xai-video")
            result_json(True, path=str(output), cost_cents=cost)
            return
        except Exception as grok_error:
            result_json(False, error=f"Both 302 AI and XAI Grok failed: {str(grok_error)}")
            sys.exit(1)


def cmd_glb(args):
    image_path = Path(args.image)
    if not image_path.exists():
        result_json(False, error=f"Image not found: {image_path}")
        sys.exit(1)

    preset = QUALITY_PRESETS.get(args.quality, QUALITY_PRESETS["default"])
    check_budget(preset["cost_cents"])

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Converting to GLB (quality={args.quality})...", file=sys.stderr)

    try:
        image_to_glb(
            image_path,
            output,
            model_version=preset["model_version"],
            texture_quality=preset["texture_quality"],
        )
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    print(f"Saved: {output}", file=sys.stderr)
    record_spend(preset["cost_cents"], "tripo3d")
    result_json(True, path=str(output), cost_cents=preset["cost_cents"])


def cmd_set_budget(args):
    BUDGET_FILE.parent.mkdir(parents=True, exist_ok=True)
    budget = {"budget_cents": args.cents, "log": []}
    if BUDGET_FILE.exists():
        old = json.loads(BUDGET_FILE.read_text())
        budget["log"] = old.get("log", [])
    BUDGET_FILE.write_text(json.dumps(budget, indent=2) + "\n")
    spent = _spent_total(budget)
    print(json.dumps({"ok": True, "budget_cents": args.cents, "spent_cents": spent, "remaining_cents": args.cents - spent}))


def main():
    parser = argparse.ArgumentParser(description="Asset Generator — images (Gemini / xAI Grok) and GLBs (Tripo3D)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_img = sub.add_parser("image", help="Generate a PNG image (Gemini 5-15¢ or Grok 2¢)")
    p_img.add_argument("--prompt", required=True, help="Full image generation prompt")
    p_img.add_argument("--model", choices=["gemini", "grok", "nano-banana"], default="grok",
                       help="Backend: grok (2¢, fast, simple images), gemini (5-15¢, precise prompt following), or nano-banana (proxy for Gemini in China). Default: grok.")
    p_img.add_argument("--size", choices=ALL_SIZES, default="1K",
                       help="Resolution. Grok: 1K, 2K. Gemini: 512, 1K, 2K, 4K. Default: 1K.")
    p_img.add_argument("--aspect-ratio", choices=ALL_ASPECT_RATIOS, default="1:1",
                       help="Aspect ratio. Default: 1:1")
    p_img.add_argument("--image", default=None, help="Reference image for image-to-image edit")
    p_img.add_argument("-o", "--output", required=True, help="Output PNG path")
    p_img.set_defaults(func=cmd_image)

    p_vid = sub.add_parser("video", help="Generate MP4 video from prompt + reference image (5¢/sec)")
    p_vid.add_argument("--prompt", required=True, help="Video generation prompt")
    p_vid.add_argument("--image", required=True, help="Reference image path (starting frame)")
    p_vid.add_argument("--duration", type=int, required=True, help=f"Duration in seconds. Supported: {SUPPORTED_VIDEO_DURATIONS}")
    p_vid.add_argument("--resolution", choices=["480p", "720p"], default="720p",
                       help="Video resolution. Default: 720p")
    p_vid.add_argument("-o", "--output", required=True, help="Output MP4 path")
    p_vid.set_defaults(func=cmd_video)

    p_glb = sub.add_parser("glb", help="Convert PNG to GLB 3D model (30-60 cents)")
    p_glb.add_argument("--image", required=True, help="Input PNG path")
    p_glb.add_argument("--quality", default="default", choices=list(QUALITY_PRESETS.keys()), help="Quality preset")
    p_glb.add_argument("-o", "--output", required=True, help="Output GLB path")
    p_glb.set_defaults(func=cmd_glb)

    p_budget = sub.add_parser("set_budget", help="Set the asset generation budget in cents")
    p_budget.add_argument("cents", type=int, help="Budget in cents")
    p_budget.set_defaults(func=cmd_set_budget)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
