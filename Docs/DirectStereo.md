# Direct stereo integration

This development interface lets another app render native stereo into macdissey
without capturing its window, packing SBS images, or asking the user to activate
3D with a shortcut. The producer renders two eye views. Macdissey owns the monitor
session, camera tracking, native-pixel output, lens controller and factory weaver.
It currently presents fullscreen on one supported Odyssey G90XF.

Users run macdissey with **Allow App Connections** enabled in its menu (disabled
by default). A client connects when it wants to present 3D, and closes when it is
finished. **Escape**, opening macdissey's menu, sleep, a display change, client
shutdown or a missed heartbeat ends playback. A producer must respect that stop;
the SDK does not automatically reconnect after the user exits.

The monitor's **Game → 3D PC** input setting must match the connected HDMI or
DisplayPort input. Video and the separate USB upstream cable are both required.
The app may request Camera permission on first activation. Direct rendering does
not require Screen Recording permission.

## Swift SDK

Use this repository as a local Swift package dependency while developing:

```swift
dependencies: [.package(path: "../odyssey3d-macos")],
targets: [
  .target(name: "YourRenderer", dependencies: [
    .product(name: "MacdisseyClient", package: "odyssey3d-macos")
  ])
]
```

The client library builds without the app's private models, shaders, calibration,
Python or native inference dependencies. It needs macOS 14 or later and Metal.

```swift
import MacdisseyClient
import Metal

let session = try await StereoSession.connect(name: "Your app")
let device = MTLCreateSystemDefaultDevice()!
let commands = device.makeCommandQueue()!
let left = try StereoEyeTexture(device: device,
    width: session.eyeWidth, height: session.eyeHeight)
let right = try StereoEyeTexture(device: device,
    width: session.eyeWidth, height: session.eyeHeight)

// In your render loop:
// 1. Render your two cameras into left.texture and right.texture.
// 2. Finish that GPU work using a command-buffer completion handler.
// 3. Submit the immutable pair. Awaiting this does not block the app's main thread.
let tracking = try await session.present(left: left.surface, right: right.surface)

// Both surfaces can now be rendered into again. Continue with another pair,
// or end playback and let macdissey restore the desktop.
await session.close()
```

`StereoSession.connect` defaults to 1920 × 2160 pixels per eye. Custom eye targets
can be 2–3840 pixels wide and 1–2160 high, permitting full 4K eye views where the
producer has the GPU budget. Both views must have the negotiated dimensions.
The host always weaves at exactly 3840 × 2160 physical output pixels. The eye
render target's pixel aspect is not the physical display's aspect: project your
scene through the physical screen rectangle, using `displaySizeMillimetres`.

## Colour and GPU synchronization

Surfaces are single-plane, top-row-first, BGRA8 with four bytes per pixel. Create
IOSurface-backed Metal targets, not private textures which cannot be shared.
`StereoEyeTexture` allocates reusable targets with render/read/write usage.

Eye pixels must already be encoded in `session.outputColorSpace`, the current
display's ICC profile. Transform other working spaces on the GPU before submitting
them. This avoids changing colour after the weaver has assigned subpixels to
eyes. The Metal demo writes device-encoded neutral greys for this reason. Its
simple lighting is diagnostic; it is not a reference for colour-managed shading.

Wait for the producer command buffer to finish before calling `present`. Keep
both eye surfaces alive and immutable until a **successful** return. Macdissey
returns them only after its GPU no longer reads them, or immediately if the pair
was dropped without reading. The acknowledgement is a GPU ownership fence, not a
scan-out timestamp. The producer can start rendering its next pair while the
host waits for the window swap. Only one presentation can be outstanding per SDK
session, and the host keeps only the latest pending pair. There is no unbounded
queue of images.

If presentation throws due to a timeout or connection loss, stop that session.
Do not overwrite its eye surfaces for a new session; allocate fresh targets.
The host may still be finishing an outstanding GPU read, and retains its own
surface rights until that completes. Explicit `close()` is preferable to relying
on deinitialization. The SDK sends idle heartbeats every 0.4 seconds; the host
expires a disconnected client after approximately two seconds.

## Tracking and lifecycle

`present` returns the latest tracking used by the host. `latestTracking` also
exposes feedback from frame acknowledgements and idle heartbeats. Feedback
contains the measured display-space midpoint in centimetres, rolling-mean IPD in
millimetres, and a monotonic host timestamp in seconds. The scene observation is
separate from the predicted position used for optical weaving; clients should
not apply optical prediction as if it were a measured scene-camera position.
`valid` is false when tracking is
stale or outside the factory viewing zone. The host independently retains the
existing lens-off/left-view fallback when no valid tracking is available.

Camera images and factory calibration are not exported by this API. For native
head-coupled rendering, use the midpoint and IPD to position your eye cameras and
the physical screen rectangle for off-axis projection. The demo demonstrates
that projection. Match your engine's axis and depth conventions deliberately;
the SDK does not supply engine-specific camera matrices or alter tracking math.

Enabling app connections allows native programs in your user account to start
tracking and receive these positions while they own the session. Turn the option
off to disable the service entirely.

Only one client can own 3D at a time. An already active manual playback session
is not interrupted by a connection request. The client receives a descriptive
failure if hardware, calibration, camera permission, or the session is unavailable.
Client startup completes only after the native output session is ready. A user
stop or disconnect during startup cancels that request.

## Metal demo

Build and run the sample from this repository:

```sh
swift run --build-system native DirectStereoDemo --seconds 10
```

This connects to the running app and **activates the physical display and 3D
lenses** for ten seconds, then restores the desktop. Press Escape to stop early.
The default scene is a miniature gallery with a tiled floor, architectural
panels, columns, pedestals, shaded spheres and rotating ring sculptures. Geometry
is uploaded once, then rendered as triangles with lighting and analytic floor
shadows. The scene uses neutral greys under the same device-colour contract as
the cube diagnostic; it does not claim general colour management for engines.
It renders into separate Metal eye textures with a head-tracked stereo scene camera by
default. The host's live tracking also routes those views to your physical eyes.
It does not create or
capture a fullscreen SBS window. `--width` and `--height` change the eye targets;
`--help` lists the options.

Rasterization defaults to four samples per pixel, falling back according to GPU
support. Fractional edge coverage prevents small camera movements from toggling
whole source pixels along the architectural lines. The two eyes reuse the same
multisample color and depth targets, using memoryless tile storage on supported
Apple GPUs and resolving directly into each shared eye texture. This keeps the
eye/output dimensions unchanged and adds no temporal image filter. Use
`--samples 1` for a diagnostic comparison with unsmoothed raster edges; GPU timing
and the actual sample count are included in `--report`.

```sh
.build/debug/DirectStereoDemo --scene gallery --seconds 30
.build/debug/DirectStereoDemo --scene cubes --seconds 20
```

Both scenes sit close to the screen plane to keep the initial stereo disparity
modest. Both eye views use the same animation timestamp. `--paused` freezes
animation while retaining optical eye tracking. The demo defaults to
`--viewpoint smooth` for head-coupled parallax: its scene camera rejects isolated
observation spikes, filters each axis using its own measured velocity, smooths
the measured eye separation and holds its last position
during invalid or stale tracking. It also advances smoothly between camera
samples. This affects only the producer's scene projection; factory tracking,
optical weaving and lens gating in macdissey stay live and unchanged. Filtering
introduces some scene-camera lag, without queuing frames or blurring the image.

Noisy depth does not raise the lateral filtering gain. A separate synthetic
stress check covers 50 Hz observations with large depth noise rendered at 165 Hz,
as well as movement response and camera dropouts. These are software checks;
physical jitter and motion quality require validation on the monitor.
Fixed-camera mode is an explicit diagnostic option and does not validate
head-tracked rendering.

Use `--viewpoint raw` to compare unsmoothed valid observations. Fixed, smoothed
and raw viewpoint choices affect only this demo's scene camera, never the host's
tracking or an integrated application's own camera. For a static scene, run:

```sh
.build/debug/DirectStereoDemo --scene gallery --seconds 20 --paused --viewpoint fixed
```

If the fixed, paused scene still shakes, scene-camera tracking is insufficient
to explain it; investigate optical output, tracking/lens transitions or display
pacing. If the picture doubles, test a
screen-plane reference before changing tracking or calibration:

```sh
.build/debug/DirectStereoDemo --seconds 15 --pattern grid
.build/debug/DirectStereoDemo --seconds 15 --pattern left
.build/debug/DirectStereoDemo --seconds 15 --pattern right
```

`grid` submits exactly the same image to both eyes: it should look flat and
single. `left` shows an L to the left eye and black to the right; cover each eye
in turn to check that the L is substantially brighter through the left eye.
`right` does the converse with an R. These isolation patterns do not use scene
depth or camera projection, but still use normal tracking and lens gating.
If normal 3D works but the identical grid doubles, the new output path needs
investigation. If the grid is clean and isolation is correct, scene disparity
or projection is the next thing to examine. `--swap-eyes` exchanges the submitted
surfaces for diagnosis; it does not change factory calibration or saved settings.
Do not use it to hide an unexplained routing failure.

For development without display activation:

```sh
swift run --build-system native DirectStereoChecks
swift build --build-system native --product DirectStereoDemo
.build/debug/DirectStereoChecks --demo .build/debug/DirectStereoDemo
```

Those checks start a private fake host, exchange actual cross-process Metal
surfaces, and run both demo scenes and isolation patterns without switching display modes,
starting a camera, or enabling lenses. `GLSurfaceChecks` additionally verifies
every output pixel of the direct eye-import path against the established CPU
path, including orientation, eye order, channels and 4K eye targets. These checks
do not constitute optical validation on the physical monitor.

For a separate offscreen check at the default 1920 × 2160 pixels per eye, run
`MACDISSEY_DEMO_NATIVE=1 .build/debug/DirectStereoChecks --demo .build/debug/DirectStereoDemo`.
The reported throughput excludes the optical weaver, window compositor and
monitor scan-out. The optional `MACDISSEY_DEMO_PREVIEW=/absolute/path/gallery.png`
captures a left-eye gallery preview during the checks; leave the native override
unset for a preview with square pixels matching the display's aspect ratio.

For an on-monitor timing/tracking report, add
`--report .build/direct-stereo/monitor-diagnostic.json` to the demo command.
The report is saved after the session closes and contains aggregate GPU/frame
timing, tracking age, validity transitions and variation in the reported head
position and IPD. It contains no camera images, absolute eye positions, factory
calibration or monitor identities. Producer GPU timing excludes the host weaver
and display scan-out. Keep your head still during a noise measurement.

Add `--trace` only when collecting a replay for a tracking investigation. It
adds at most 2048 observations relative to the first sample: elapsed seconds,
X/Y/Z displacement in millimetres and IPD change in millimetres. The initial
absolute position and IPD are not recorded. Keep these local diagnostic files
outside version control. Run
`.build/direct-stereo/DirectStereoViewpointChecks --replay path/to/report.json`
after `sh scripts/check-direct-stereo-viewpoint.sh` to measure projected motion
offline; the replay uses a nominal 60 cm distance, not the user's recorded
absolute viewing position.

## C / Objective-C++ interface and deployment

The `MacdisseyIPC` product exposes `MacdisseyIPC.h` for native engine plugins.
Use `mds_client_create(mds_service_name())`, then `mds_client_exchange` with
`MDS_BEGIN`, `MDS_FRAME`, `MDS_PING`, and `MDS_END`. Keep the returned session ID,
send strictly increasing frame sequences, and obey the same GPU ownership and
ICC rules as the Swift SDK. Calls are synchronous and must run on a dedicated
render/IPC worker, one at a time per client. `MDSInfo` returns output dimensions,
refresh, physical size and tracking. `mds_client_copy_icc` returns the negotiated
ICC profile. The C header documents statuses and ownership.

The service is a per-user Mach endpoint advertised only while the running app
allows connections: `io.github.fulviuus.macdissey.direct.<uid>`. It uses no TCP
listener, helper installation, global IOSurface IDs, or image serialization.
IOSurface Mach capabilities are transferred with the frames. The host checks
the kernel audit trailer's user and process identity, exclusive session token,
surface format, dimensions, allocation bounds and sequence. A stale client
cannot submit to a later session.

The initial SDK targets native apps in the same logged-in user's bootstrap
namespace. App Sandbox clients need an appropriate Mach lookup entitlement or
an entitled native integration component; a sandboxed browser cannot call this
interface directly. There are no Unity, Unreal, OpenXR, browser or Samsung SDK
compatibility adapters in this implementation. Such adapters can use the native
client API while keeping the hardware-specific work inside macdissey.

## Performance boundaries

The direct path removes ScreenCaptureKit capture, capture colour conversion,
CPU pixel transport, stereo-layout decoding and AI depth inference. Two GPU blits
feed the original combined weaver texture, followed by the existing calibrated
draw. This is zero CPU image-copy, not zero GPU work. Camera tracking, the optical
weaver, the window compositor and display scan-out still contribute latency.

Direct mode requests the active display refresh rate instead of the ordinary
60 Hz capture cadence. Actual frame rate and latency depend on producer GPU
work, eye-target size, tracking, macOS scheduling and monitor timing. A control
round-trip or an offscreen blit benchmark is not an end-to-end latency measurement.
