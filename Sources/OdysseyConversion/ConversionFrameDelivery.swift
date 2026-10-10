import Foundation

/// One conversion session publishes directly into the renderer's latest-frame
/// slot. No main-actor task can retain a backlog of output-pool buffers. A closed
/// session cannot publish into a later session's renderer.
public final class ConversionFrameDelivery<Frame>: @unchecked Sendable {
  private let lock = NSLock()
  private var consumer: ((Frame) -> Void)?
  public init() {}
  public func connect(_ consumer: @escaping (Frame) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    self.consumer = consumer
  }
  public func submit(_ frame: Frame) {
    lock.lock()
    defer { lock.unlock() }
    consumer?(frame)
  }
  public func disconnect() {
    lock.lock()
    defer { lock.unlock() }
    consumer = nil
  }
}
