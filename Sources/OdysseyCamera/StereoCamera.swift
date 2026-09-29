import AVFoundation
import Foundation
import OdysseyCore

public enum StereoCameraError: Error, LocalizedError {
  case permission, unavailable, unsupportedFormat, malformedFrame
  public var errorDescription: String? {
    switch self {
    case .permission:
      return "Allow Odyssey 3D to use the camera in System Settings → Privacy & Security → Camera."
    case .unavailable:
      return "Connect the Odyssey stereo camera through the monitor’s USB upstream cable."
    case .unsupportedFormat: return "The Odyssey camera’s 1280 × 480 stereo format is unavailable."
    case .malformedFrame: return "The stereo camera returned an unexpected image format."
    }
  }
}

/// Uses only the monitor's 04e8:20d7 camera. Both views are delivered in one
/// frame, so they share a timestamp. It never opens another attached webcam.
public final class StereoCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let session = AVCaptureSession()
  private let processing = DispatchQueue(label: "Odyssey.stereo-camera", qos: .userInitiated)
  private let tracker: StereoCameraTracker
  private var configured = false
  public var frame: ((StereoCameraTrackingFrame) -> Void)?
  public var failure: ((Error) -> Void)?
  public init(tracker: StereoCameraTracker) {
    self.tracker = tracker
    super.init()
  }
  public static var authorized: Bool {
    AVCaptureDevice.authorizationStatus(for: .video) == .authorized
  }
  public static func requestAuthorization() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .video)
  }
  public static func now() -> Double { CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock())) }

  /// Call start/stop from the same background lifecycle queue. Frame and
  /// failure callbacks run on the processing queue.
  public func start() throws {
    guard Self.authorized else { throw StereoCameraError.permission }
    guard !configured else { return }
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.external], mediaType: .video, position: .unspecified)
    let candidates = discovery.devices.filter { $0.uniqueID.lowercased().hasSuffix("4e820d7") }
    guard candidates.count == 1, let device = candidates.first else {
      throw StereoCameraError.unavailable
    }
    let formats = device.formats.filter {
      let size = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
      return size.width == 1280 && size.height == 480
    }
    guard
      let format = formats.first(where: {
        CMFormatDescriptionGetMediaSubType($0.formatDescription)
          == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
      }) ?? formats.first,
      let rate = format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })
    else {
      throw StereoCameraError.unsupportedFormat
    }
    let input = try AVCaptureDeviceInput(device: device)
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    // Windows decodes MJPEG directly to full-range JPEG luminance. AVF can
    // deliver full range as well; requesting video range would crush it.
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
    output.setSampleBufferDelegate(self, queue: processing)
    session.beginConfiguration()
    guard session.canAddInput(input), session.canAddOutput(output) else {
      session.commitConfiguration()
      throw StereoCameraError.unsupportedFormat
    }
    session.addInput(input)
    session.addOutput(output)
    do {
      try device.lockForConfiguration()
      device.activeFormat = format
      device.activeVideoMinFrameDuration = rate.minFrameDuration
      device.activeVideoMaxFrameDuration = rate.minFrameDuration
      device.unlockForConfiguration()
    } catch {
      session.commitConfiguration()
      throw error
    }
    session.commitConfiguration()
    configured = true
    session.startRunning()
  }
  public func stop() {
    session.stopRunning()
    processing.sync {}  // Finish the in-flight inference before teardown.
    session.beginConfiguration()
    for input in session.inputs { session.removeInput(input) }
    for output in session.outputs { session.removeOutput(output) }
    session.commitConfiguration()
    configured = false
  }
  public func captureOutput(
    _ output: AVCaptureOutput, didOutput sample: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    do {
      guard let pixel = CMSampleBufferGetImageBuffer(sample),
        CVPixelBufferGetPlaneCount(pixel) >= 1,
        CVPixelBufferGetPixelFormatType(pixel) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
      else {
        throw StereoCameraError.malformedFrame
      }
      CVPixelBufferLockBaseAddress(pixel, .readOnly)
      let width = CVPixelBufferGetWidthOfPlane(pixel, 0)
      let height = CVPixelBufferGetHeightOfPlane(pixel, 0)
      let stride = CVPixelBufferGetBytesPerRowOfPlane(pixel, 0)
      guard let data = CVPixelBufferGetBaseAddressOfPlane(pixel, 0), width == 1280, height == 480,
        stride >= width
      else {
        CVPixelBufferUnlockBaseAddress(pixel, .readOnly)
        throw StereoCameraError.malformedFrame
      }
      let bytes = Array(
        UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: stride * height)
      )
      CVPixelBufferUnlockBaseAddress(pixel, .readOnly)
      let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
      frame?(
        try tracker.update(
          pixels: bytes, width: width, height: height, stride: stride,
          captureTimestamp: timestamp, now: Self.now))
    } catch { failure?(error) }
  }
}
