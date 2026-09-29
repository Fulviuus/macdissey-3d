#!/usr/bin/env python3
"""Prepare pinned native ONNX Runtime; the application does not embed Python."""

import importlib.util
import platform
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFIX = ROOT / ".tools/onnx-native"
spec = importlib.util.spec_from_file_location(
    "prepare_inference", ROOT / "scripts/prepare-inference.py"
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def main():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise SystemExit("The pinned face runtime requires Apple silicon macOS")
    helper.DOWNLOADS.mkdir(parents=True, exist_ok=True)
    headers = {
        "onnxruntime_c_api.h": "e035e30c27e74c8c00e0f483e576e12b4067d17f12e9237fd6eff8b346c9b381",
        "onnxruntime_error_code.h": "5ce3b054e798eced8d14f5b86e98692fd33470463f96194ce0700a2d53dd8721",
        "onnxruntime_ep_c_api.h": "e6c986c9e98583f8113b2c6bc3864814883b806d501cf24da4d239c45753e235",
    }
    for name, digest in headers.items():
        source = helper.fetch(
            "onnxruntime-1.30.0-" + name,
            "https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/"
            + name,
            digest,
        )
        target = PREFIX / "include" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
    wheel = helper.fetch(
        "onnxruntime-1.30.0-cp314-cp314-macosx_14_0_arm64.whl",
        "https://files.pythonhosted.org/packages/6a/03/05c9a9234688757d2876ddecf80bba908561ee11debf125bc1a427ae6f48/onnxruntime-1.30.0-cp314-cp314-macosx_14_0_arm64.whl",
        "8b6169c16a48429890d2f4a0c774ebf54dfe9066a998514aad0518a16d398547",
    )
    with zipfile.ZipFile(wheel) as archive:
        for source, relative in [
            (
                "onnxruntime/capi/libonnxruntime.1.30.0.dylib",
                "lib/libonnxruntime.1.30.0.dylib",
            ),
            ("onnxruntime/LICENSE", "licenses/LICENSE"),
            ("onnxruntime/ThirdPartyNotices.txt", "licenses/ThirdPartyNotices.txt"),
        ]:
            target = PREFIX / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(source))
    for name in ["libonnxruntime.dylib", "libonnxruntime.1.dylib"]:
        link = PREFIX / "lib" / name
        if not link.is_symlink():
            link.symlink_to("libonnxruntime.1.30.0.dylib")
    print("Prepared pinned native ONNX Runtime 1.30.0")


if __name__ == "__main__":
    main()
