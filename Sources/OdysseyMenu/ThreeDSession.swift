import AppKit
import OdysseyCamera
import OdysseyCore
import OdysseyRendering
import ScreenCaptureKit

private final class ThreeDCaptureSink: NSObject, SCStreamOutput, SCStreamDelegate {
  weak var renderer: GLSBSRenderer?
  var colors: DisplayColorPipeline?
  private var reportedColorSpace = false
  var failure: ((Error) -> Void)?
  func stream(
    _ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType
  ) {
    guard type == .screen, sample.isValid,
      let info = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
        as? [[SCStreamFrameInfo: Any]],
      let raw = info.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
      let pixel = sample.imageBuffer
    else { return }
    do {
      guard let colors else { throw DisplayColorError.invalidFrame }
      // With colorSpaceName unset, ScreenCaptureKit supplies the display
      // space directly. Honour explicit buffer metadata if supplied.
      let sourceSpace =
        CVImageBufferGetColorSpace(pixel)?.takeUnretainedValue() ?? colors.outputColorSpace
      if !reportedColorSpace {
        print(
          "Capture colour profile matches display: \(CFEqual(sourceSpace,colors.outputColorSpace)); pre-weave conversion \(CFEqual(sourceSpace,colors.outputColorSpace) ? "bypassed" : "required")"
        )
        fflush(stdout)
        reportedColorSpace = true
      }
      renderer?.submit(try colors.convert(pixel, from: sourceSpace))
    } catch { failure?(error) }
  }
  func stream(_ stream: SCStream, didStopWithError error: Error) { failure?(error) }
}

@MainActor final class ThreeDSession {
  private var stream: SCStream?, sink: ThreeDCaptureSink?, window: NSWindow?,
    renderer: GLSBSRenderer?
  private var camera: StereoCamera?, lens: LensOutput?
  private var savedMode: CGDisplayMode?, displayID: CGDirectDisplayID = 0
  private var watchdog: OutputWatchdogClient?
  private let captureQueue = DispatchQueue(label: "Odyssey.3D-capture", qos: .userInteractive)
  var failure: ((Error) -> Void)?
  var status: ((String) -> Void)?
  var allowsLensActivation = true
  var renderedFrames: Int { renderer?.renderedFrames ?? 0 }
  var layout = SBSLayout.fullWidth { didSet { renderer?.layout = layout } }
  private var weaving = false

  func start(on screen: NSScreen, profile: FactoryProfile) async throws {
    guard CGPreflightScreenCaptureAccess() else {
      CGRequestScreenCaptureAccess()
      throw AppError.unavailable(
        "Allow macdissey 3d in System Settings → Privacy & Security → Screen & System Audio Recording, then reopen the app."
      )
    }
    if !StereoCamera.authorized {
      guard await StereoCamera.requestAuthorization() else { throw StereoCameraError.permission }
    }
    guard
      let port = Hardware.devices().first(where: { $0.vendorID == 0x354b && $0.productID == 0x0116 }
      )?.serialPort,
      let resources = Bundle.main.resourceURL
    else { throw StereoCameraError.unavailable }
    let tracker = try await Task.detached {
      try StereoCameraTracker(
        camera: profile.camera, tracker: profile.tracker,
        faceModelURL: resources.appendingPathComponent("Models/face.onnx"),
        landmarkModelURL: resources.appendingPathComponent("Models/landmarks.tflite"))
    }.value
    try Task.checkCancellation()
    let id = Hardware.displayID(screen)
    guard let original = CGDisplayCopyDisplayMode(id),
      let modes = CGDisplayCopyAllDisplayModes(
        id, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary) as? [CGDisplayMode],
      let native = modes.filter({ $0.pixelWidth == 3840 && $0.pixelHeight == 2160 }).sorted(by: {
        let first = abs($0.width - original.width)
        let second = abs($1.width - original.width)
        return first == second ? $0.refreshRate > $1.refreshRate : first < second
      }).first
    else {
      throw AppError.unavailable("No native 3840 × 2160 output mode is available on this display.")
    }
    print(
      "3D display mode: \(native.pixelWidth)×\(native.pixelHeight) at \(native.refreshRate) Hz (mode \(native.ioDisplayModeID))"
    )
    fflush(stdout)
    do {
      let lens = LensOutput { [weak self] error in Task { @MainActor in self?.failure?(error) } }
      self.lens = lens
      try await lens.start(port: port)
      displayID = id
      savedMode = original
      if original.ioDisplayModeID != native.ioDisplayModeID {
        guard CGDisplaySetDisplayMode(id, native, nil) == .success else {
          throw AppError.unavailable("Cannot switch Odyssey to native 4K output.")
        }
        try await Task.sleep(nanoseconds: 300_000_000)
      }
      try Task.checkCancellation()
      guard let activeScreen = NSScreen.screens.first(where: { Hardware.displayID($0) == id }),
        let renderer = try GLSBSRenderer(size: activeScreen.frame.size, profile: profile)
      else { throw WeaverRenderFailure.unavailable }
      self.renderer = renderer
      renderer.layout = layout
      renderer.failure = { [weak self] error in self?.failure?(error) }
      renderer.presented = { [weak self, weak lens] valid in
        guard let self else { return }
        lens?.request(valid && self.allowsLensActivation)
        guard self.weaving != valid else { return }
        self.weaving = valid
        self.status?(valid ? "3D active · tracking eyes" : "Waiting for eyes in the viewing area")
      }
      // ScreenCaptureKit does not list a menu-only process until it owns
      // a WindowServer window. Publish the overlay before building the
      // exclusion filter, then capture only after exclusion is verified.
      let outputColorSpace = CGDisplayCopyColorSpace(id)
      let window = NSWindow(
        contentRect: activeScreen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      window.hasShadow = false
      window.ignoresMouseEvents = true
      window.backgroundColor = .black
      window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
      window.collectionBehavior = [
        .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
      ]
      window.contentView = renderer
      // Colour matching must finish before subpixel eye assignment.
      // Match the display profile here to prevent a second conversion.
      window.colorSpace = NSColorSpace(cgColorSpace: outputColorSpace)
      window.setFrame(activeScreen.frame, display: true)
      self.window = window
      window.orderFrontRegardless()
      let content = try await SCShareableContent.excludingDesktopWindows(
        false, onScreenWindowsOnly: false)
      guard let display = content.displays.first(where: { $0.displayID == id }),
        let application = content.applications.first(where: {
          $0.processID == ProcessInfo.processInfo.processIdentifier
        })
      else {
        throw AppError.unavailable("Cannot capture the Odyssey while excluding the 3D overlay.")
      }
      let sink = ThreeDCaptureSink()
      sink.renderer = renderer
      sink.colors = DisplayColorPipeline(outputColorSpace: outputColorSpace)
      sink.failure = { [weak self] error in Task { @MainActor in self?.failure?(error) } }
      self.sink = sink
      let config = SCStreamConfiguration()
      config.width = 3840
      config.height = 2160
      config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
      config.queueDepth = 3
      // The default capture colour space is the display's own profile.
      // Avoid sRGB conversion, which also discards wide-gamut colours.
      config.pixelFormat = kCVPixelFormatType_32BGRA
      config.showsCursor = false
      config.capturesAudio = false
      let stream = SCStream(
        filter: SCContentFilter(
          display: display, excludingApplications: [application], exceptingWindows: []),
        configuration: config, delegate: sink)
      try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: captureQueue)
      self.stream = stream
      try await stream.startCapture()
      let camera = StereoCamera(tracker: tracker)
      self.camera = camera
      camera.frame = { [weak renderer] value in renderer?.track(value.pose) }
      camera.failure = { [weak self] error in Task { @MainActor in self?.failure?(error) } }
      try await Task.detached { try camera.start() }.value
      try Task.checkCancellation()
      let watchdog = OutputWatchdogClient()
      try watchdog.start(port: port, display: id, mode: original)
      self.watchdog = watchdog
      renderer.begin()
      status?("Waiting for eyes in the viewing area")
    } catch {
      await stop()
      throw error
    }
  }
  func stop() async {
    renderer?.presented = nil
    await lens?.stop()
    lens = nil
    weaving = false
    renderer?.end()
    window?.orderOut(nil)
    window?.close()
    window = nil
    if let stream { try? await stream.stopCapture() }
    stream = nil
    sink = nil
    if let camera { await Task.detached { camera.stop() }.value }
    camera = nil
    renderer = nil
    if let savedMode, CGDisplayIsOnline(displayID) != 0 {
      _ = CGDisplaySetDisplayMode(displayID, savedMode, nil)
    }
    savedMode = nil
    displayID = 0
    watchdog?.stop()
    watchdog = nil
  }
}
