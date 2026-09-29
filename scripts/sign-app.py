#!/usr/bin/env python3
"""Sign a bundle, reusing an optional private local development identity."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def main():
    bundle = Path(sys.argv[1]).resolve()
    identity = os.environ.get("MACDISSEY_SIGNING_IDENTITY")
    extra = []
    config = Path(__file__).resolve().parent.parent / ".local-assets/signing/identity.json"
    if identity is None and config.exists():
        local = json.loads(config.read_text())
        identity = local["identity"]
        keychain = local["keychain"]
        password = Path(local["passwordFile"]).read_text()
        # Feed the dedicated keychain password over stdin, never command-line
        # arguments or build logs. This keychain contains only our signing key.
        command = shlex.join(["unlock-keychain", "-p", password, keychain])
        subprocess.run(
            ["/usr/bin/security", "-i"], input=command + "\n", text=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True,
        )
        extra = ["--keychain", keychain, "--timestamp=none"]
    identity = identity or "-"
    for path in [
        bundle / "Contents/Frameworks/libLiteRt.dylib",
        bundle / "Contents/Frameworks/libonnxruntime.1.dylib",
        bundle / "Contents/MacOS/7zz",
        bundle,
    ]:
        subprocess.run(["codesign", "--force", "--sign", identity, *extra, str(path)], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)


if __name__ == "__main__":
    main()
