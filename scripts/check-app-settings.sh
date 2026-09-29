#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/settings-checks
swiftc Sources/OdysseyMenu/KeyboardShortcut.swift Sources/OdysseyMenu/HotKey.swift \
    Tests/AppSettingsChecks/main.swift -o .build/settings-checks/AppSettingsChecks
.build/settings-checks/AppSettingsChecks
swiftc -parse-as-library Sources/OdysseyMenu/KeyboardShortcut.swift \
    Sources/OdysseyMenu/SettingsWindowController.swift Tests/SettingsLayoutChecks/main.swift \
    -o .build/settings-checks/SettingsLayoutChecks
.build/settings-checks/SettingsLayoutChecks .build/settings-checks/settings-layout.png
swiftc -parse-as-library Sources/OdysseyMenu/OutputDisplayState.swift \
    Tests/OutputDisplayStateChecks/main.swift -o .build/settings-checks/OutputDisplayStateChecks
.build/settings-checks/OutputDisplayStateChecks
swiftc -parse-as-library Sources/OdysseyMenu/AlertPresenter.swift \
    Tests/AlertLifecycleChecks/main.swift -o .build/settings-checks/AlertLifecycleChecks
python3 - <<'PY'
import subprocess
result = subprocess.run([".build/settings-checks/AlertLifecycleChecks"],
                        capture_output=True, text=True, timeout=10, check=True)
assert "PASS: Quit reaches" in result.stdout, result.stdout + result.stderr
print(result.stdout, end="")
PY
