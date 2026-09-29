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
