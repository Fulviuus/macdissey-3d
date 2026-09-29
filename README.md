# macdissey 3d

<img src="Resources/Artwork/AppIcon.png" alt="macdissey 3d app icon" width="128" height="128">

A macOS menu bar app for watching side-by-side (SBS) 3D video on the Samsung
Odyssey 3D G90XF. It captures the display, tracks the viewer with the monitor's
stereo camera, and renders the two views using the monitor's factory calibration.

macdissey 3d is an independent interoperability project, unaffiliated with Samsung
or Leia. Playback has been verified on one 27-inch G90XF. Multi-viewer handover and
full equivalence with the Windows software have not been established.

## Requirements

- Apple silicon Mac running macOS 14 or later.
- Samsung Odyssey 3D G90XF connected by both video and USB upstream cables.
- A connection that exposes a native 3840 × 2160 display mode.
- Camera and Screen Recording permissions for the app.

The desktop can use another resolution or scaling setting. During 3D playback,
the app selects a native 4K pixel mode and restores the previous mode on exit.
Arbitrary scaled output is not supported for the final optical rendering.

## Install the app

Download the Apple silicon ZIP from [Releases](https://github.com/Fulviuus/macdissey-3d/releases/latest),
unzip it, and drag **macdissey 3d.app** into **Applications**.

**The app is not signed with an Apple Developer ID or notarized by Apple.**
macOS Gatekeeper may block the first launch. If you trust this download:

1. Open the app once, then dismiss the security alert.
2. Go to **System Settings → Privacy & Security** and scroll to **Security**.
3. Click **Open Anyway** beside the message about macdissey 3d, authenticate if
   prompted, and confirm **Open**.

This approves this app individually. See [Apple's instructions](https://support.apple.com/en-gb/102445).
Then grant **Camera** and **Screen Recording** (called **Screen & System Audio
Recording** on newer macOS versions) permissions when prompted. Quit and reopen
the app after changing permissions if requested.

## Watching a video

1. Open an SBS video in a player and make it fullscreen on the Odyssey.
2. Choose **Activate 3D** in the menu bar, or press **Control–Option–Command–3**.
3. Look toward the monitor's camera. Press **Escape** or choose **Deactivate 3D**
   to return to the desktop.

Use **Stretch to fill** for videos whose two eye views are horizontally squeezed.
Use **Remove black bars** for full-width SBS video displayed with top and bottom
bars. This crops the bars before filling the screen.

**Settings** contains **Launch at login** and the keyboard shortcut editor.
The monochrome menu bar icon adapts to the system appearance.

Protected video may not be available to ScreenCaptureKit. The app does not bypass
capture restrictions imposed by a player or streaming service.

## Building

Install the Xcode Command Line Tools, Python 3, CMake, Ninja, and 7-Zip 26.03.
The build scripts download checksum-pinned OpenCV 4.3.0, LiteRT 2.2.0, and
ONNX Runtime 1.30.0 dependencies. Python is used only for building; playback is
native Swift and C++.

### Private runtime assets

Four vendor assets are required but are not included in this source repository:

```text
.local-assets/
├── Models/
│   ├── face.onnx
│   └── landmarks.tflite
└── Weaver/
    ├── vertex.glsl
    └── fragment.glsl
```

Supply the compatible recovered face model, landmark model, and original weaver
shaders from your installation. A standard Windows installer is not accepted
directly by the build script. If you already have a working macdissey 3d bundle,
you can import just these four files:

```sh
python3 scripts/import-assets.py "/path/to/macdissey 3d.app"
```

Alternatively, set `MACDISSEY_ASSETS` to a directory with the same structure.
Assets stay local and are ignored by Git. Per-monitor calibration is read from the
connected monitor at runtime and cached in
`~/Library/Application Support/Odyssey3D/Calibration`; it is never part of the
source or build assets.

```sh
sh scripts/build-app.sh
open "dist/macdissey 3d.app"
```

The resulting app is locally ad-hoc signed. The internal executable name and
bundle identifier remain stable to preserve existing settings and permissions.
See [Third-party notices](THIRD_PARTY_NOTICES.md) for dependency attribution.

## Checks

```sh
sh scripts/check.sh
```

The compact suite checks fragmented controller replies, malformed calibration,
display color conversion, shortcut persistence/conflicts, and settings layout.
It needs macOS with a logged-in graphical session, but does not enable the lenses
or require private model assets. Checks are standalone executables because the
Command Line Tools installation does not include XCTest.

An optional hardware integration check is available in a built app:

```sh
"dist/macdissey 3d.app/Contents/MacOS/OdysseyMenu" --integration-smoke-test
```

Quit the regular app before running it. This check uses the connected monitor,
camera, and screen-capture permission, briefly switches to 4K, and restores the
display afterward. It keeps the lenses off and does not establish optical quality.

## Source layout

| Directory | Purpose |
| --- | --- |
| `Sources/OdysseyMenu` | Menu bar UI, capture, rendering coordination, controller access |
| `Sources/OdysseyCore` | Protocol, calibration decoding, and tracking mathematics |
| `Sources/OdysseyCamera` | Stereo camera acquisition and tracking pipeline |
| `Sources/OdysseyVision` | Native OpenCV pose and image processing |
| `Sources/OdysseyInference` | Native LiteRT and ONNX Runtime adapters |
| `Sources/OdysseyGL` | OpenGL interface for the original weaver shaders |
| `Sources/OdysseyRendering` | Display color conversion |
| `Sources/OdysseyMonitor` | Optional monitor notification bridge client |
| `Resources` | App metadata, original icon artwork, and license texts |
| `Tests` | Small regression suite using synthetic inputs |
| `scripts` | Dependency preparation, build, and validation |

The renderer uses macOS OpenGL to run the original weaver shaders. OpenGL is
deprecated by Apple; its compiler deprecation warnings are expected.

The optional notification bridge is inactive unless its separately managed local
helper is present. Normal playback does not require installing that helper.
