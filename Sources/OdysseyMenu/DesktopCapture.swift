import AppKit
import OdysseyRendering
import ScreenCaptureKit

/// Owns a pair of display-aligned captures. A new pair is started when focus
/// changes, so frames from different layer assignments cannot be mixed.
@MainActor
final class DesktopCapture: NSObject, SCStreamDelegate {
  private let displayID: CGDirectDisplayID
  private let renderer: GLSBSRenderer
  private let colorSpace: CGColorSpace
  private let failure: (Error) -> Void
  private let layerBackgrounds = [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)]
  private var streams: [SCStream] = []
  private var sinks: [DesktopLayerSink] = []
  private var frames: DesktopFrames?
  private var refreshTask: Task<Void, Never>?
  private var signature: [CGWindowID]?
  private var regions: [CGRect] = []
  private var stopped = false
  private(set) var sceneChanges = 0

  init(
    displayID: CGDirectDisplayID, renderer: GLSBSRenderer,
    colorSpace: CGColorSpace, failure: @escaping (Error) -> Void
  ) {
    self.displayID = displayID
    self.renderer = renderer
    self.colorSpace = colorSpace
    self.failure = failure
  }

  func start() async throws {
    try await refresh()
    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: 33_333_333)
          guard let self, !self.stopped else { return }
          try await self.refresh()
        } catch is CancellationError { return } catch {
          self?.failure(error)
          return
        }
      }
    }
  }

  private func foregroundIDs() -> [CGWindowID] {
    let ownPID = ProcessInfo.processInfo.processIdentifier
    let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let bounds = CGDisplayBounds(displayID)
    let list =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0)
      as? [[String: Any]] ?? []
    var focus: CGWindowID?
    var fallback: CGWindowID?
    var overlays: [CGWindowID] = []
    var rectangles: [CGWindowID: CGRect] = [:]
    for info in list {
      guard let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
        let id = info[kCGWindowNumber as String] as? CGWindowID,
        let layer = info[kCGWindowLayer as String] as? Int,
        let dictionary = info[kCGWindowBounds as String] as? [String: Any],
        let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
        rect.intersects(bounds),
        (info[kCGWindowAlpha as String] as? Double ?? 1) > 0
      else { continue }
      rectangles[id] = rect
      if layer == 0, rect.width >= 100, rect.height >= 60 {
        if fallback == nil { fallback = id }
        if pid == frontPID, focus == nil { focus = id }
      } else if layer > 0, layer < 1000 {
        // Menus, sheets, and floating controls stay at the interaction plane.
        overlays.append(id)
      }
    }
    if let focus = focus ?? fallback { overlays.append(focus) }
    let scaleX = 3840 / bounds.width
    let scaleY = 2160 / bounds.height
    regions = overlays.compactMap { id in
      guard let rect = rectangles[id] else { return nil }
      // Dock owns a transparent display-sized surface. Its full bounds must
      // not flatten the whole desktop; use the reserved Dock strip below.
      if id != (focus ?? fallback), rect.width >= bounds.width,
        rect.height >= bounds.height
      {
        return nil
      }
      return CGRect(
        x: (rect.minX - bounds.minX) * scaleX, y: (rect.minY - bounds.minY) * scaleY,
        width: rect.width * scaleX, height: rect.height * scaleY)
    }
    if let screen = NSScreen.screens.first(where: { Hardware.displayID($0) == displayID }) {
      let frame = screen.frame
      let visible = screen.visibleFrame
      // Keep menu bar and the visible Dock at the real pointer's depth.
      let strips = [
        CGRect(x: 0, y: 0, width: frame.width, height: frame.maxY - visible.maxY),
        CGRect(
          x: 0, y: frame.maxY - visible.minY, width: frame.width,
          height: visible.minY - frame.minY),
        CGRect(x: 0, y: 0, width: visible.minX - frame.minX, height: frame.height),
        CGRect(
          x: visible.maxX - frame.minX, y: 0,
          width: frame.maxX - visible.maxX, height: frame.height),
      ]
      regions += strips.filter { $0.width > 0 && $0.height > 0 }.map {
        CGRect(
          x: $0.minX * scaleX, y: $0.minY * scaleY,
          width: $0.width * scaleX, height: $0.height * scaleY)
      }
    }
    return Array(Set(overlays)).sorted()
  }

  private func refresh() async throws {
    let ids = foregroundIDs()
    frames?.updateRegions(regions)
    guard signature != ids else { return }
    let content = try await SCShareableContent.excludingDesktopWindows(
      false, onScreenWindowsOnly: true)
    try Task.checkCancellation()
    guard !stopped else { return }
    guard let display = content.displays.first(where: { $0.displayID == displayID }),
      let ownApp = content.applications.first(where: {
        $0.processID == ProcessInfo.processInfo.processIdentifier
      })
    else { throw AppError.unavailable("The desktop display is no longer available.") }
    let foreground = content.windows.filter { ids.contains($0.windowID) }
    await stopStreams()
    try Task.checkCancellation()
    guard !stopped else { return }
    let frames = DesktopFrames(
      renderer: renderer, colorSpace: colorSpace,
      needsForeground: !foreground.isEmpty, failure: failure)
    frames.updateRegions(regions)
    self.frames = frames
    // Both filters capture a display. Window/app inclusion streams cause
    // macOS to replace the focused window's traffic lights with sharing UI.
    let back = SCContentFilter(
      display: display, excludingApplications: [ownApp], exceptingWindows: foreground)
    let front = SCContentFilter(
      display: display, excludingApplications: [ownApp], exceptingWindows: [])
    if #available(macOS 14.2, *), !foreground.isEmpty {
      back.includeMenuBar = false
      front.includeMenuBar = true
    }
    let filters = foreground.isEmpty ? [back] : [back, front]
    for (index, filter) in filters.enumerated() {
      let config = SCStreamConfiguration()
      config.width = 3840
      config.height = 2160
      config.pixelFormat = kCVPixelFormatType_32BGRA
      config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
      config.queueDepth = 3
      config.showsCursor = false  // Keep the real cursor at its original click coordinates.
      config.capturesAudio = false
      if #available(macOS 14.2, *) { config.includeChildWindows = true }
      config.backgroundColor = layerBackgrounds[index]
      let sink = DesktopLayerSink(frames: frames, foreground: index == 1)
      let stream = SCStream(filter: filter, configuration: config, delegate: self)
      try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: frames.queue)
      sinks.append(sink)
      streams.append(stream)
      try await stream.startCapture()
    }
    signature = ids
    sceneChanges += 1
    print("Desktop depth: \(foreground.count) foreground surfaces, scene \(sceneChanges)")
    fflush(stdout)
  }

  private func stopStreams() async {
    await frames?.stop()
    frames = nil
    let old = streams
    streams = []
    for stream in old { try? await stream.stopCapture() }
    sinks = []
  }

  func stop() async {
    stopped = true
    let task = refreshTask
    refreshTask = nil
    task?.cancel()
    await task?.value
    await stopStreams()
  }

  nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
    Task { @MainActor [weak self] in
      guard let self, !self.stopped, self.streams.contains(where: { $0 === stream }) else { return }
      self.failure(error)
    }
  }
}

private final class DesktopLayerSink: NSObject, SCStreamOutput {
  let frames: DesktopFrames
  let foreground: Bool
  init(frames: DesktopFrames, foreground: Bool) {
    self.frames = frames
    self.foreground = foreground
  }
  func stream(
    _ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer,
    of type: SCStreamOutputType
  ) {
    guard type == .screen, sample.isValid,
      let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
        as? [[SCStreamFrameInfo: Any]],
      let raw = attachments.first?[.status] as? Int,
      SCFrameStatus(rawValue: raw) == .complete, let buffer = sample.imageBuffer
    else { return }
    frames.receive(buffer, foreground: foreground)
  }
}

/// Every mutable field is confined to queue, including stop and timer teardown.
private final class DesktopFrames: @unchecked Sendable {
  let queue = DispatchQueue(label: "Macdissey.desktop-frames", qos: .userInteractive)
  private weak var renderer: GLSBSRenderer?
  private let colors: DisplayColorPipeline
  private let compositor = DesktopCompositor()
  private let needsForeground: Bool
  private let failure: (Error) -> Void
  private var background: CVPixelBuffer?, foreground: CVPixelBuffer?
  private var timer: DispatchSourceTimer?
  private var stopped = false, dirty = false
  private var count = 0
  private var regions: [CGRect] = []

  func updateRegions(_ regions: [CGRect]) {
    queue.async {
      guard !self.stopped, self.regions != regions else { return }
      self.regions = regions
      self.dirty = true
    }
  }

  init(
    renderer: GLSBSRenderer, colorSpace: CGColorSpace, needsForeground: Bool,
    failure: @escaping (Error) -> Void
  ) {
    self.renderer = renderer
    colors = DisplayColorPipeline(outputColorSpace: colorSpace)
    self.needsForeground = needsForeground
    self.failure = failure
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: 1.0 / 60.0)
    timer.setEventHandler { [weak self] in self?.render() }
    self.timer = timer
    timer.resume()
  }
  func receive(_ buffer: CVPixelBuffer, foreground: Bool) {
    guard !stopped else { return }
    do {
      let space =
        CVImageBufferGetColorSpace(buffer)?.takeUnretainedValue() ?? colors.outputColorSpace
      let converted = try colors.convert(buffer, from: space)
      if foreground { self.foreground = converted } else { background = converted }
      dirty = true
    } catch { report(error) }
  }
  private func render() {
    guard !stopped, dirty, let background, !needsForeground || foreground != nil else { return }
    do {
      let output = try compositor.compose(
        background: background, foreground: foreground,
        colorSpace: colors.outputColorSpace, foregroundRegions: regions)
      renderer?.submit(output)
      dirty = false
      count += 1
      if count == 1 {
        print("Desktop stereo frame ready: 7680×2160")
        fflush(stdout)
      }
    } catch { report(error) }
  }
  private func report(_ error: Error) {
    stopped = true
    timer?.cancel()
    Task { @MainActor [failure] in failure(error) }
  }
  func stop() async {
    await withCheckedContinuation { continuation in
      queue.async {
        self.stopped = true
        self.timer?.cancel()
        self.timer = nil
        self.background = nil
        self.foreground = nil
        print("Desktop scene stopped after \(self.count) composed frames")
        continuation.resume()
      }
    }
  }
}
