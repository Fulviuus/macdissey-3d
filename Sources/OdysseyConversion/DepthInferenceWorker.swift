import Foundation

/// Carries each prediction with its source frame. One in-flight or completed
/// pair bounds memory and prevents older depth being applied to newer video.
final class DepthInferenceWorker<Frame>: @unchecked Sendable {
  struct Result {
    let frame: Frame
    let depth: [Float]
    let changedScene: Bool
  }
  private let queue = DispatchQueue(label: "macdissey.depth-inference", qos: .userInitiated)
  private let lock = NSLock()
  private let predict: ([Float], inout [Float]) throws -> Void
  private let outputCount: Int
  private let changedScene: () -> Bool
  private var busy = false, stopped = false
  private var latest: Result?
  private var failure: Error?
  var didComplete: (() -> Void)?

  init(
    outputCount: Int, changedScene: @escaping () -> Bool = { false },
    predict: @escaping ([Float], inout [Float]) throws -> Void
  ) {
    self.outputCount = outputCount
    self.predict = predict
    self.changedScene = changedScene
  }

  /// The converter may advance when a prediction has finished, consuming its
  /// paired result before starting the latest waiting capture.
  var canAdvance: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !busy && !stopped
  }

  var canSubmit: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !busy && latest == nil && !stopped
  }

  @discardableResult func submit(_ input: [Float], frame: Frame) -> Bool {
    lock.lock()
    guard !busy && latest == nil && !stopped else {
      lock.unlock()
      return false
    }
    busy = true
    lock.unlock()
    queue.async { [self] in
      var output = [Float](repeating: 0, count: outputCount)
      var predictionError: Error?
      do { try predict(input, &output) } catch { predictionError = error }
      lock.lock()
      busy = false
      let notify = !stopped
      if notify {
        latest =
          predictionError == nil
          ? Result(frame: frame, depth: output, changedScene: changedScene()) : nil
        failure = predictionError
      }
      lock.unlock()
      if notify { didComplete?() }
    }
    return true
  }

  func takeLatest() throws -> Result? {
    lock.lock()
    defer { lock.unlock() }
    if let failure { throw failure }
    let result = latest
    latest = nil
    return result
  }

  func stop() async {
    cancel()
    await withCheckedContinuation { continuation in
      queue.async { continuation.resume() }
    }
  }

  private func cancel() {
    lock.lock()
    stopped = true
    latest = nil
    lock.unlock()
  }
}
