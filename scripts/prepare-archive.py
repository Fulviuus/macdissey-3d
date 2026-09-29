#!/usr/bin/env python3
"""Prepare the separately executed native 7-Zip helper and its license texts."""

import hashlib
import shutil
import subprocess
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
destination = ROOT / ".tools/sevenzip-native"
destination.mkdir(parents=True, exist_ok=True)
helper = shutil.which("7zz")
if not helper:
    raise SystemExit("Install the native archive helper with: brew install sevenzip")
version = subprocess.check_output([helper, "i"], text=True)
if "7-Zip (z) 26.03" not in version:
    raise SystemExit(
        "This build expects sevenzip 26.03; review and pin newer versions before updating."
    )
source = destination / "7z2603-src.tar.xz"
if not source.exists():
    urllib.request.urlretrieve(
        "https://github.com/ip7z/7zip/releases/download/26.03/7z2603-src.tar.xz", source
    )
if (
    hashlib.sha256(source.read_bytes()).hexdigest()
    != "9cbde5099c6deb73691b0579063da5827522ccbbcba3f0020fd04e8c8c16c0d4"
):
    raise SystemExit("7-Zip source checksum mismatch")
licenses = destination / "licenses"
licenses.mkdir(exist_ok=True)
with tarfile.open(source) as archive:
    for name in ("License.txt", "copying.txt", "unRarLicense.txt"):
        with archive.extractfile("DOC/" + name) as stream:
            (licenses / name).write_bytes(stream.read())
staged = destination / "7zz.new"
shutil.copyfile(helper, staged)
staged.chmod(0o755)
staged.replace(destination / "7zz")
print("Prepared native 7-Zip 26.03 helper and licenses")
