#!/usr/bin/env python3
"""Prepare pinned native LiteRT headers/library; no Python runtime is bundled."""

import hashlib
import platform
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFIX = ROOT / ".tools/litert-native"
DOWNLOADS = ROOT / ".cache/downloads"
SDK_SHA = "0aa619d80aef27303ad9c6e3759a20110f77e7b11ade9b68061b8c6e5904b0c6"
WHEEL_SHA = "90fe45c8a0557e15b873f685e33ecaa2302782a8cb09a1ca754d536d5fa30945"


def fetch(name, url, digest):
    path = DOWNLOADS / name
    if not path.exists():
        temporary = path.with_suffix(path.suffix + ".part")
        urllib.request.urlretrieve(url, temporary)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != digest:
            raise RuntimeError("Unexpected download digest: " + name)
        temporary.replace(path)
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        raise RuntimeError("Unexpected archive digest: " + name)
    return path


def main():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise SystemExit(
            "The pinned native inference runtime currently supports Apple silicon macOS"
        )
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    sdk = fetch(
        "litert_cc_sdk-2.2.0.zip",
        "https://github.com/google-ai-edge/LiteRT/releases/download/v2.2.0/litert_cc_sdk.zip",
        SDK_SHA,
    )
    wheel = fetch(
        "ai_edge_litert-2.2.0-cp312-cp312-macosx_12_0_arm64.whl",
        "https://files.pythonhosted.org/packages/1f/09/778399be516866419e3de6257e4f7ab6b8563b2fc204b6353f2361a8b025/ai_edge_litert-2.2.0-cp312-cp312-macosx_12_0_arm64.whl",
        WHEEL_SHA,
    )
    license = fetch(
        "LiteRT-2.2.0-LICENSE",
        "https://raw.githubusercontent.com/google-ai-edge/LiteRT/v2.2.0/LICENSE",
        "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4",
    )
    with zipfile.ZipFile(sdk) as archive:
        for name in archive.namelist():
            prefix = "litert_cc_sdk/litert/"
            if name.startswith(prefix) and name.endswith((".h", ".h.in")):
                relative = Path(name.removeprefix("litert_cc_sdk/"))
                if ".." in relative.parts:
                    raise RuntimeError("Unsafe SDK archive path")
                path = PREFIX / "include" / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.read(name))
    template = PREFIX / "include/litert/build_common/build_config.h.in"
    template.with_suffix("").write_text(
        template.read_text()
        .replace(
            "#cmakedefine01 LITERT_BUILD_CONFIG_DISABLE_GPU",
            "#define LITERT_BUILD_CONFIG_DISABLE_GPU 0",
        )
        .replace(
            "#cmakedefine01 LITERT_BUILD_CONFIG_DISABLE_NPU",
            "#define LITERT_BUILD_CONFIG_DISABLE_NPU 0",
        )
    )
    library = PREFIX / "lib/libLiteRt.dylib"
    library.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(wheel) as archive:
        library.write_bytes(archive.read("ai_edge_litert/libLiteRt.dylib"))
    licenses = PREFIX / "licenses"
    licenses.mkdir(parents=True, exist_ok=True)
    (licenses / "LiteRT-LICENSE").write_bytes(license.read_bytes())
    print("Prepared pinned native LiteRT 2.2.0 headers and library")


if __name__ == "__main__":
    main()
