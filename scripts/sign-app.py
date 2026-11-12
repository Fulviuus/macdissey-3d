#!/usr/bin/env python3
"""Sign a bundle for local development or Developer ID distribution."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


def main():
    bundle = Path(sys.argv[1]).resolve()
    identity = os.environ.get("MACDISSEY_SIGNING_IDENTITY")
    distribution = os.environ.get("MACDISSEY_DISTRIBUTION_SIGNING") == "1"
    if distribution and (not identity or identity == "-"):
        raise SystemExit("Distribution signing requires MACDISSEY_SIGNING_IDENTITY.")
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
    if distribution:
        extra = ["--options", "runtime", "--timestamp"]
    for path in [
        bundle / "Contents/Frameworks/libLiteRt.dylib",
        bundle / "Contents/Frameworks/libonnxruntime.1.dylib",
        bundle / "Contents/MacOS/7zz",
        bundle,
    ]:
        entitlements = []
        if distribution and path == bundle:
            entitlements = [
                "--entitlements",
                str(Path(__file__).resolve().parent.parent / "Resources/macdissey.entitlements"),
            ]
        subprocess.run(
            ["codesign", "--force", "--sign", identity, *extra, *entitlements, str(path)],
            check=True,
        )
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)
    if distribution:
        details = subprocess.run(
            ["codesign", "--display", "--verbose=4", str(bundle)],
            capture_output=True, text=True, check=True,
        ).stderr
        if "Authority=Developer ID Application:" not in details or "Timestamp=" not in details:
            raise SystemExit(
                "Distribution signature must use a timestamped Developer ID Application certificate."
            )


if __name__ == "__main__":
    main()
