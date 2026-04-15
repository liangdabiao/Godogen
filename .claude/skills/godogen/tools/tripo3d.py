"""Tripo3D API client for image-to-3D model conversion.

API docs: https://platform.tripo3d.ai/docs/generation

Model versions:
- P1-20260311: Best low-poly generation, ~2s mesh, game-optimized topology
- v3.1-20260211: HD textures, detailed geometry
"""

import os
import time
from pathlib import Path

import requests

API_BASE = "https://api.tripo3d.ai/v2/openapi"

MODEL_P1 = "P1-20260311"
MODEL_V31 = "v3.1-20260211"


def get_api_key() -> str:
    key = os.environ.get("TRIPO3D_API_KEY")
    if not key:
        raise ValueError("TRIPO3D_API_KEY environment variable not set")
    return key


def create_task(
    image_path: Path,
    model_version: str = MODEL_P1,
    texture_quality: str = "standard",
) -> str:
    """Create image-to-model task, returns task_id."""
    api_key = get_api_key()
    headers = {"Authorization": f"Bearer {api_key}"}

    # Upload image
    upload_url = f"{API_BASE}/upload"
    with open(image_path, "rb") as f:
        files = {"file": (image_path.name, f, "image/png")}
        resp = requests.post(upload_url, headers=headers, files=files)
        resp.raise_for_status()
        upload_data = resp.json()

    image_token = upload_data["data"]["image_token"]

    payload = {
        "type": "image_to_model",
        "model_version": model_version,
        "file": {"type": "png", "file_token": image_token},
        "texture": True,
        "pbr": True,
    }

    if texture_quality != "standard":
        payload["texture_quality"] = texture_quality

    task_url = f"{API_BASE}/task"
    resp = requests.post(task_url, headers=headers, json=payload)
    resp.raise_for_status()
    return resp.json()["data"]["task_id"]


def poll_task(task_id: str, timeout: int = 300, interval: int = 5) -> dict:
    """Poll task until completion, returns task result."""
    api_key = get_api_key()
    headers = {"Authorization": f"Bearer {api_key}"}
    url = f"{API_BASE}/task/{task_id}"

    start = time.time()
    while time.time() - start < timeout:
        resp = requests.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()["data"]

        status = data["status"]
        if status == "success":
            return data
        elif status in ("failed", "cancelled", "unknown"):
            raise RuntimeError(f"Task {task_id} failed with status: {status}")

        time.sleep(interval)

    raise TimeoutError(f"Task {task_id} timed out after {timeout}s")


def download_model(task_result: dict, output_path: Path) -> Path:
    """Download GLB model from task result."""
    model_url = task_result["output"].get("pbr_model") or task_result["output"].get("base_model")
    if not model_url:
        raise ValueError(f"No model URL in task output: {task_result['output'].keys()}")
    resp = requests.get(model_url)
    resp.raise_for_status()
    output_path.write_bytes(resp.content)
    return output_path


def image_to_glb(
    image_path: Path,
    output_path: Path,
    model_version: str = MODEL_P1,
    texture_quality: str = "standard",
    timeout: int = 300,
) -> Path:
    """Convert image to GLB model using Tripo3D API."""
    task_id = create_task(image_path, model_version=model_version, texture_quality=texture_quality)
    print(f"  Tripo3D task: {task_id} (model={model_version})")

    result = poll_task(task_id, timeout=timeout)
    print(f"  Tripo3D completed")

    return download_model(result, output_path)
