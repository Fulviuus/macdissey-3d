#!/usr/bin/env python3
"""Rebuild MIT-licensed SR-Loom shader ports; requires glslang and spirv-cross."""

from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
ENTRIES = [
    "PSMain", "PSFmtHalfSBS", "PSFmtFullSBS", "PSFmtTAB", "PSFmtRow",
    "PSFmtColumn", "PSFmtChecker", "PSFmtFramePack", "PSFmtAnaglyph",
    "PSDown", "PSAnaDisp", "PSAnaDesc", "PSAnaRefine", "PSAnaFill", "PSAnaSmooth",
]
HEADER = (
    "// Generated from SR-Loom Converter.hlsl (MIT). Copyright (c) 2026 SR Loom contributors.\n"
    "// Upstream d0b93f308d5aaf7c57fd02f5a3bd61402fe31f8b. See Resources/Licenses/SR-Loom-LICENSE.txt.\n"
    "// Regenerate with scripts/translate-stereo-shaders.py.\n"
)


def main():
    destination = ROOT / "Resources/StereoShaders"
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        for entry in ENTRIES:
            spv = Path(temp) / (entry + ".spv")
            out = destination / (entry + ".metal")
            subprocess.run([
                "glslang", "-D", "-V", "-Os", "--target-env", "vulkan1.1",
                "-S", "frag", "-e", entry,
                str(ROOT / "Resources/SRLoom/Converter.hlsl"), "-o", str(spv),
            ], check=True)
            subprocess.run([
                "spirv-cross", str(spv), "--msl", "--msl-version", "30000",
                "--rename-entry-point", entry, "main0", "frag", "--output", str(out),
            ], check=True)
            source = "\n".join(line.rstrip() for line in out.read_text().splitlines())
            out.write_text(HEADER + source.rstrip() + "\n")


if __name__ == "__main__":
    main()
