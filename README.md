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

### Updating

Quit the app before replacing it, and keep one installed copy in **Applications**.
Public releases are ad-hoc signed, so an update may require granting Camera or
Screen Recording permission again. If the toggle is enabled but capture is still
denied, remove the old Screen Recording entry with **−**, add the installed app
with **+**, enable it, then quit and reopen it.

## Watching a video

1. Open an SBS video in a player and make it fullscreen on the Odyssey.
2. Choose **Activate 3D** in the menu bar, or press **Control–Option–Command–3**.
3. Look toward the monitor's camera. Press **Escape**, press the activation
   shortcut again, or open the macdissey menu to stop 3D.

Use **Stretch to fill** for videos whose two eye views are horizontally squeezed.
Use **Remove black bars** for full-width SBS video displayed with top and bottom
bars. This crops the bars before filling the screen.

**VLC on macOS:** enable **Use the native fullscreen mode** in VLC's
**Preferences → Interface**, save, and restart VLC before entering fullscreen.
With VLC 3.0.23, this resolved horizontal misalignment and spillover between the
eye views observed with its legacy fullscreen mode.

**Settings** contains **Launch at login**, the SBS shortcut editor, and a reference
for every keyboard shortcut, including conversion controls and how to exit.
The monochrome menu bar icon adapts to the system appearance.

Protected video may not be available to ScreenCaptureKit. The app does not bypass
capture restrictions imposed by a player or streaming service.

## Keyboard shortcuts

Shortcuts work from other apps, including fullscreen players. In Settings,
**⌃** means Control, **⇧** Shift, **⌥** Option, and **⌘** Command.

| Action | Shortcut | Available in |
| --- | --- | --- |
| Start SBS video / stop the active 3D mode | Control–Option–Command–3 (customizable in Settings) | Any app |
| Start 2D conversion / stop the active 3D mode | Control–Shift–2 | Any app |
| Show Depth and Pop-Out values | Control–Shift–1 | Active 2D conversion |
| Decrease 3D Depth | Control–Shift–3 | Active 2D conversion |
| Increase 3D Depth | Control–Shift–4 | Active 2D conversion |
| Decrease Pop-Out | Control–Shift–5 | Active 2D conversion |
| Increase Pop-Out | Control–Shift–6 | Active 2D conversion |
| Stop any 3D mode | Escape | Any active 3D mode |

Conversion shortcuts are fixed. Desktop 3D, picture layout, and Quit are available
from the menu. Opening the macdissey menu also stops 3D. While editing the SBS
shortcut in Settings, Escape cancels recording the new shortcut.

## 2D video conversion — experimental

The app can synthesize two eye views from an ordinary fullscreen
2D video. Choose **Convert 2D Video to 3D (Experimental)** or press
**Control–Shift–2**. Press **Escape** or open the app menu to stop.

The original player shortcuts listed above control the effect, with values
appearing briefly in the image. Depth changes the separation between the
synthesized views; Pop-Out moves the depth range relative to the screen. These
controls apply only to conversion, not to recorded SBS video or Desktop 3D.

This port uses the recovered Samsung Player 1.5.0 fast depth model and conversion
stages, translated to Metal, with the recovered control formulas. It processes
1920 × 1080 pixels per eye before native 4K weaving. It is an experimental native
port: playback and smoothness have been verified on one setup, and numerical
checks cover individual stages. Complete Windows output equivalence has not been
established. Performance and estimated depth depend on the scene and Mac.

Image processing uses batched Metal commands. Depth inference uses Core ML with
GPU acceleration, falling back to the CPU if accelerated initialization fails.
The weights remain unchanged, although accelerator arithmetic can produce small
numerical differences. The first activation can take several seconds to compile
the model; compiled models are cached locally for subsequent activations.

Conversion is included in v0.5.0 and later. Building it from source requires the
additional private assets described below.

## Desktop 3D — experimental

**Desktop 3D adds an experimental depth effect to your windows.** Expect rough
edges and higher resource use than ordinary desktop work. SBS video playback
remains the app's main purpose.

Choose **Try Desktop 3D (Experimental)** to keep the front window at the screen
surface while placing the remaining desktop slightly behind it. Click another
window to change the foreground. Press **Escape** or the activation shortcut to
exit. Opening the macdissey menu stops 3D before displaying the menu.

The effect uses two flat depth layers and keeps normal window and pointer
positions. It targets up to 60 captured frames per second; actual performance
depends on the Mac and what is on screen. Rounded corners, translucent windows,
and an automatically hidden Dock can have imperfect depth boundaries. Menus,
Spaces, focus transitions, and text readability still need broader testing.
There is no perspective change as you move your head. The usual shortcut starts
SBS video mode; desktop mode is activated separately from the menu.

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
For experimental 2D conversion, also supply `Conversion/model.onnx` (the recovered
fast model), `Conversion/samples8.f32`, and `Conversion/Shaders/` (the translated
conversion programs). These vendor assets are optional, remain private, and are
not supplied or extracted by the public build scripts. The four-file import
command above does not import conversion assets.

Assets stay local and are ignored by Git. Per-monitor calibration is read from the
connected monitor at runtime and cached in
`~/Library/Application Support/Odyssey3D/Calibration`; it is never part of the
source or build assets.

```sh
sh scripts/build-app.sh
open "dist/macdissey 3d.app"
```

By default, the app is ad-hoc signed. Its bundle identifier preserves settings,
but ad-hoc signatures change identity when code changes and may require granting
screen recording permission again. For development, set
`MACDISSEY_SIGNING_IDENTITY` to a persistent code-signing identity in your Keychain.
The build also supports a private local identity configured in the ignored
`.local-assets/signing/identity.json`; its `identity`, `keychain`, and `passwordFile`
fields identify a dedicated signing keychain. Signing failures stop the build;
they never silently fall back to ad-hoc signing. Set the environment variable to
`-` explicitly when packaging an ad-hoc build for distribution.

Keep only one launchable installation registered with macOS. Launching test
bundles with the same identifier can make permission-driven relaunches select
the wrong copy. Store backups with a suffix such as `.app.backup`.
See [Third-party notices](THIRD_PARTY_NOTICES.md) for dependency attribution.

## Checks

```sh
sh scripts/check.sh
```

The compact suite checks fragmented controller replies, malformed calibration,
display color conversion, desktop layer composition, CPU/GPU upload equivalence,
shortcut persistence/conflicts, window layout, alert dismissal, and display changes.
It also checks conversion control ranges. Set `MACDISSEY_CONVERSION_ASSETS` to
the private `Conversion` directory to additionally exercise model inference,
stereo synthesis, paused-frame adjustment, and shutdown with synthetic input.
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
Use `--desktop-smoke-test` instead for desktop mode; add `--extended-check` to run
either integration check for 60 seconds.
Use `--conversion-smoke-test` for 2D conversion when its private assets are present.

## Source layout

| Directory | Purpose |
| --- | --- |
| `Sources/OdysseyMenu` | Menu bar UI, capture, rendering coordination, controller access |
| `Sources/OdysseyCore` | Protocol, calibration decoding, and tracking mathematics |
| `Sources/OdysseyCamera` | Stereo camera acquisition and tracking pipeline |
| `Sources/OdysseyVision` | Native OpenCV pose and image processing |
| `Sources/OdysseyInference` | Native LiteRT and ONNX Runtime adapters |
| `Sources/OdysseyConversion` | Experimental monocular depth and stereo synthesis |
| `Sources/OdysseyGL` | OpenGL interface for the original weaver shaders |
| `Sources/OdysseyRendering` | Display color conversion and desktop composition |
| `Sources/OdysseyMonitor` | Optional monitor notification bridge client |
| `Resources` | App metadata, original icon artwork, and license texts |
| `Tests` | Small regression suite using synthetic inputs |
| `scripts` | Dependency preparation, build, and validation |

The renderer uses macOS OpenGL to run the original weaver shaders. OpenGL is
deprecated by Apple; its compiler deprecation warnings are expected.

The optional notification bridge is inactive unless its separately managed local
helper is present. Normal playback does not require installing that helper.

## License

The original macdissey 3d source code is available under the [MIT License](LICENSE).
Third-party components retain their own licenses; see
[Third-party notices](THIRD_PARTY_NOTICES.md). Recovered vendor models, shaders,
and per-monitor calibration are not covered by the project’s MIT license.
