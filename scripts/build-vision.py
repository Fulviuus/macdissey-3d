#!/usr/bin/env python3
"""Build the minimal pinned OpenCV dependency for native pose estimation."""

import hashlib
import json
import os
import platform
import shutil
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = "68bc40cbf47fdb8ee73dfaf0d9c6494cd095cf6294d99de445ab64cf853d278a"
VERSION = "4.3.0"
PREFIX = ROOT / ".tools/opencv43-install"
BUILD = ROOT / ".tools/opencv43-build"
SOURCE = ROOT / f".tools/opencv-{VERSION}"
STAMP = PREFIX / "odyssey-build.json"


def main():
    sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
    options = {
        "CMAKE_POLICY_VERSION_MINIMUM": "3.5",
        "CMAKE_BUILD_TYPE": "Release",
        "CMAKE_INSTALL_PREFIX": str(PREFIX),
        "CMAKE_OSX_DEPLOYMENT_TARGET": "14.0",
        "CMAKE_CXX_FLAGS": "-ffp-contract=off",
        "CMAKE_C_FLAGS": "-ffp-contract=off",
        "BUILD_LIST": "core,imgproc,calib3d",
        "BUILD_SHARED_LIBS": "OFF",
        "BUILD_TESTS": "OFF",
        "BUILD_PERF_TESTS": "OFF",
        "BUILD_EXAMPLES": "OFF",
        "BUILD_opencv_apps": "OFF",
        "BUILD_JAVA": "OFF",
        "BUILD_opencv_python2": "OFF",
        "BUILD_opencv_python3": "OFF",
        "BUILD_ZLIB": "OFF",
        "ZLIB_INCLUDE_DIR": sdk + "/usr/include",
        "ZLIB_LIBRARY": sdk + "/usr/lib/libz.tbd",
        **{
            "WITH_" + x: "OFF"
            for x in (
                "IPP",
                "OPENCL",
                "LAPACK",
                "EIGEN",
                "TBB",
                "ITT",
                "PNG",
                "JPEG",
                "TIFF",
                "OPENEXR",
                "JASPER",
                "WEBP",
                "FFMPEG",
                "CAROTENE",
            )
        },
    }
    stamp = {
        "build_revision": 2,
        "source_sha256": SHA,
        "architecture": platform.machine(),
        "options": options,
    }
    libraries = [
        "libopencv_core.a",
        "libopencv_imgproc.a",
        "libopencv_calib3d.a",
        "libopencv_features2d.a",
        "libopencv_flann.a",
    ]
    if (
        STAMP.exists()
        and json.loads(STAMP.read_text()) == stamp
        and all((PREFIX / "lib" / p).is_file() for p in libraries)
    ):
        print("Pinned native vision dependency is ready")
        return
    archive = ROOT / f".cache/downloads/opencv-{VERSION}.tar.gz"
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        urllib.request.urlretrieve(
            f"https://github.com/opencv/opencv/archive/refs/tags/{VERSION}.tar.gz",
            archive,
        )
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA:
        raise SystemExit("OpenCV archive does not match the pinned digest")
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    if not SOURCE.exists():
        subprocess.run(["tar", "-xzf", str(archive), "-C", str(SOURCE.parent)], check=True)
    log = ROOT / ".build/logs/native-vision-build.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as output:
        subprocess.run(
            ["cmake", "-S", str(SOURCE), "-B", str(BUILD), "-G", "Ninja"]
            + [f"-D{k}={v}" for k, v in options.items()],
            check=True,
            stdout=output,
            stderr=subprocess.STDOUT,
        )
        subprocess.run(
            [
                "cmake",
                "--build",
                str(BUILD),
                "--parallel",
                str(min(8, os.cpu_count() or 2)),
            ],
            check=True,
            stdout=output,
            stderr=subprocess.STDOUT,
        )
        subprocess.run(
            ["cmake", "--install", str(BUILD)],
            check=True,
            stdout=output,
            stderr=subprocess.STDOUT,
        )
    licenses = PREFIX / "share/licenses/opencv4"
    licenses.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE / "LICENSE", licenses / "OpenCV-LICENSE")
    for name, path in [
        ("Carotene", "3rdparty/carotene/src/absdiff.cpp"),
        ("FLANN", "modules/flann/include/opencv2/flann/defines.h"),
    ]:
        block = (SOURCE / path).read_text().split("*/", 1)[0] + "*/\n"
        (licenses / (name + "-LICENSE")).write_text(block)
    STAMP.write_text(json.dumps(stamp, indent=2) + "\n")
    print("Built pinned OpenCV dependency:", PREFIX)


if __name__ == "__main__":
    main()
