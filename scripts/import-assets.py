#!/usr/bin/env python3
"""Import only the four private runtime assets from an existing app bundle."""

import argparse
import shutil
from pathlib import Path

ASSETS = (
    "Models/face.onnx",
    "Models/landmarks.tflite",
    "Weaver/vertex.glsl",
    "Weaver/fragment.glsl",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Existing macdissey 3d.app bundle")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / ".local-assets",
        help="Destination for private build assets",
    )
    args = parser.parse_args()
    source = args.app / "Contents/Resources"
    for name in ASSETS:
        path = source / name
        if not path.is_file() or path.stat().st_size == 0:
            parser.error(f"Missing or empty asset: {name}")
        if (args.output / name).exists():
            parser.error(f"Destination already contains {name}; choose a new output directory")
    args.output.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name in ASSETS:
        destination = args.output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, destination)
    print("Imported four runtime assets; no calibration or device data was copied.")


if __name__ == "__main__":
    main()
