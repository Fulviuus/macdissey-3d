#!/usr/bin/env python3
"""Acquire pinned public Small assets and compile bundled Core ML models.

All generated assets and developer dependencies stay in ignored build folders.
The application performs no downloads and needs no Python installation.
"""
import hashlib
import json
import os
import pathlib
import platform
import shutil
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / ".tools"
OUTPUT = ROOT / ".build/video-depth-small"
REVISION = "4f5ae23172ba60fd7bc11ef671cca678842c7072"
SHA = "85c583474dcafda4d417776431343afcdfdfc97952d8ec00029d3452c55a05a2"
URL = "https://huggingface.co/AEmotionStudio/Video-Depth-Anything-Small/resolve/50aafe6478a8932fd1380df4847feb009962afad/video_depth_anything_vits.safetensors?download=true"
REQUIREMENTS = ["coremltools==9.0", "torch==2.7.0", "torchvision==0.22.0", "numpy==1.26.4",
                "safetensors==0.5.3", "einops==0.8.1", "easydict==1.13", "opencv-python==4.11.0.86"]


def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""): hasher.update(block)
    return hasher.hexdigest()


def main():
    exporter = ROOT / "scripts/export-video-depth-networks.py"
    identity = {"exporter": digest(exporter), "builder": digest(pathlib.Path(__file__)),
                "checkpoint": SHA, "upstream": REVISION, "dependencies": REQUIREMENTS,
                "compiler_os": platform.mac_ver()[0]}
    marker = OUTPUT / "compiled.json"
    if marker.exists():
        manifest = json.loads(marker.read_text())
        files = manifest.get("files", {})
        if manifest.get("identity") == identity and files and all(
            (OUTPUT / name).is_file() and digest(OUTPUT / name) == sha for name, sha in files.items()
        ):
            print("Bundled VDA Small Core ML models are current.")
            return
    TOOLS.mkdir(exist_ok=True)
    supplied_python = os.environ.get("MACDISSEY_DEPTH_EXPORT_PYTHON")
    if supplied_python:
        python = supplied_python
    else:
        interpreter = shutil.which("python3.12")
        if not interpreter:
            raise SystemExit("Building bundled VDA Small needs Python 3.12 (developers only). See README.md.")
        environment = TOOLS / "video-depth-venv"
        python = str(environment / "bin/python")
        if not pathlib.Path(python).exists(): subprocess.run([interpreter, "-m", "venv", str(environment)], check=True)
        subprocess.run([python, "-m", "pip", "install", "--disable-pip-version-check", *REQUIREMENTS], check=True)
    upstream = TOOLS / "video-depth-source"
    if not (upstream / ".git").exists():
        subprocess.run(["git", "clone", "--filter=blob:none", "--no-checkout",
                        "https://github.com/DepthAnything/Video-Depth-Anything.git", str(upstream)], check=True)
    current = subprocess.check_output(["git", "-C", str(upstream), "rev-parse", "HEAD"], text=True).strip()
    if current != REVISION or not (upstream / "video_depth_anything/video_depth_stream.py").is_file():
        subprocess.run(["git", "-C", str(upstream), "fetch", "--depth=1", "origin", REVISION], check=True)
        subprocess.run(["git", "-C", str(upstream), "checkout", "--detach", REVISION], check=True)
    weights = TOOLS / "video-depth-small.safetensors"
    if not weights.exists() or digest(weights) != SHA:
        staging = weights.with_suffix(".download")
        try:
            print("Downloading pinned public VDA Small checkpoint…", flush=True)
            with urllib.request.urlopen(URL, timeout=300) as source, staging.open("wb") as destination:
                shutil.copyfileobj(source, destination)
            if staging.stat().st_size != 116362340 or digest(staging) != SHA:
                raise RuntimeError("VDA Small checkpoint failed size/SHA-256 verification")
            staging.replace(weights)
        finally: staging.unlink(missing_ok=True)
    staging = OUTPUT.with_name("video-depth-small-staging")
    if staging.exists(): shutil.rmtree(staging)
    try:
        subprocess.run([python, str(exporter), "--upstream", str(upstream), "--weights", str(weights),
                        "--scratch", str(ROOT / ".build/video-depth-export"), "--output", str(staging)], check=True)
        files = {str(path.relative_to(staging)): digest(path) for path in staging.rglob("*") if path.is_file()}
        (staging / "compiled.json").write_text(json.dumps({"identity": identity, "files": files}, indent=2) + "\n")
        if OUTPUT.exists(): shutil.rmtree(OUTPUT)
        staging.replace(OUTPUT)
    finally:
        if staging.exists(): shutil.rmtree(staging)
    print("Bundled VDA Small Core ML models compiled and verified.")


if __name__ == "__main__":
    main()
