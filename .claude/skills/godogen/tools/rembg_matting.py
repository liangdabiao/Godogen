"""Remove solid-color background using 302 AI API."""

import argparse
import json
import os
import sys
from pathlib import Path

import requests
from PIL import Image

# 302 AI API configuration
API_KEY = os.environ.get("THREE_ZERO_TWO_AI_KEY", "")
if not API_KEY:
    raise ValueError("THREE_ZERO_TWO_AI_KEY environment variable not set")
API_URL = "https://api.302.ai/recraft/v1/images/removeBackground"

def remove_background_api(input_path: Path, output_path: Path, preview: bool = False):
    """Remove background using 302 AI API."""
    # Load image file
    with open(input_path, "rb") as f:
        image_data = f.read()
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Accept": "application/json"
    }
    
    # Prepare multipart form data
    files = {
        "file": (input_path.name, image_data, "image/png")
    }
    
    data = {
        "response_format": "url"
    }
    
    max_retries = 3
    retry_delay = 5  # seconds
    
    for attempt in range(max_retries):
        try:
            print(f"Sending request to 302 AI API (attempt {attempt+1}/{max_retries})...", file=sys.stderr)
            response = requests.post(API_URL, headers=headers, files=files, data=data, timeout=120)
            
            print(f"API response status: {response.status_code}", file=sys.stderr)
            
            if response.status_code == 200:
                data = response.json()
                
                if "image" in data and "url" in data["image"]:
                    image_url = data["image"]["url"]
                    print(f"Extracted image URL: {image_url}", file=sys.stderr)
                    
                    # Download the image
                    img_response = requests.get(image_url, timeout=120, verify=False)
                    img_response.raise_for_status()
                    
                    # Save the image
                    output_path.write_bytes(img_response.content)
                    print(f"Saved: {output_path}", file=sys.stderr)
                    
                    # Generate QA preview if requested
                    if preview:
                        # Create a simple preview by compositing on white background
                        img = Image.open(output_path).convert("RGBA")
                        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
                        bg.paste(img, mask=img.split()[3])
                        preview_path = output_path.with_stem(output_path.stem + "_qa")
                        bg.convert("RGB").save(preview_path)
                        print(f"QA preview: {preview_path}", file=sys.stderr)
                    
                    return True
                else:
                    print("No image found in API response", file=sys.stderr)
                    return False
            elif response.status_code == 422:
                data = response.json()
                if "error" in data:
                    error_info = data["error"]
                    print(f"API error: {error_info.get('message_cn', error_info.get('message', 'Unknown error'))}", file=sys.stderr)
                    print(f"Error code: {error_info.get('err_code', 'Unknown code')}", file=sys.stderr)
                else:
                    print(f"API error: {response.status_code} - {response.text}", file=sys.stderr)
                return False
            elif response.status_code == 500:
                print(f"API error: 500 - 服务器内部错误", file=sys.stderr)
                return False
            else:
                print(f"API error: {response.status_code} - {response.text}", file=sys.stderr)
                return False
        except requests.exceptions.Timeout:
            print(f"Request timed out. Retrying in {retry_delay} seconds...", file=sys.stderr)
            import time
            time.sleep(retry_delay)
        except Exception as e:
            print(f"Error: {str(e)}", file=sys.stderr)
            return False
    
    print(f"All {max_retries} attempts failed", file=sys.stderr)
    return False


def process_batch(input_dir: Path, output_dir: Path, preview: bool = False):
    """Process all PNGs in input_dir using 302 AI API."""
    output_dir.mkdir(parents=True, exist_ok=True)
    frames = sorted(input_dir.glob("*.png"))
    if not frames:
        print("No PNG files found", file=sys.stderr)
        sys.exit(1)

    print(f"Processing {len(frames)} frames...", file=sys.stderr)

    for i, frame_path in enumerate(frames):
        print(f"  [{i+1}/{len(frames)}] {frame_path.name}", file=sys.stderr)
        out_path = output_dir / frame_path.name
        remove_background_api(frame_path, out_path, preview)

    print(f"\nBatch complete: {len(frames)} frames → {output_dir}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Remove solid-color background using 302 AI API")
    parser.add_argument("input", nargs="?", help="Input image path (single mode)")
    parser.add_argument("-o", "--output", help="Output path (file for single, directory for batch)")
    parser.add_argument("--batch", metavar="DIR",
                        help="Batch mode: process all PNGs in DIR")
    parser.add_argument("--preview", action="store_true",
                        help="Generate QA preview on white background")
    args = parser.parse_args()

    if args.batch:
        if not args.output:
            print("Error: --batch requires -o OUTPUT_DIR", file=sys.stderr)
            sys.exit(1)
        process_batch(Path(args.batch), Path(args.output), args.preview)
        return

    if not args.input:
        parser.error("input is required in single mode (or use --batch DIR)")

    input_path = Path(args.input)
    output_path = Path(args.output) if args.output else \
        input_path.with_stem(input_path.stem + "_nobg")

    print(f"Processing: {input_path}", file=sys.stderr)
    
    if remove_background_api(input_path, output_path, args.preview):
        print("\nSuccess!", file=sys.stderr)
    else:
        print("\nFailed to remove background", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
