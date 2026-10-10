import Foundation

/// Holds one prepared runtime. All creation and ownership changes are serialized;
/// inference itself belongs exclusively to the converter which checked it out.
final class DepthRuntimeCache<Runtime: AnyObject>: @unchecked Sendable {
  private let queue = DispatchQueue(label: "macdissey.depth-preparation", qos: .utility)
  private var key: String?
  private var runtime: Runtime?
  private var leased = false

  func prepare(
    key: String, completion: ((Result<Void, Error>) -> Void)? = nil,
    load: @escaping () throws -> Runtime
  ) {
    queue.async { [self] in
      do {
        _ = try available(key: key, load: load)
        completion?(.success(()))
      } catch {
        completion?(.failure(error))
        // Activation retries and reports any background preparation failure.
      }
    }
  }

  func acquire(key: String, load: () throws -> Runtime) throws -> Runtime {
    try queue.sync {
      let value = try available(key: key, load: load)
      guard !leased else { throw CacheFailure.alreadyInUse }
      leased = true
      return value
    }
  }

  func release(_ value: Runtime) {
    queue.async { [self] in
      if runtime === value { leased = false }
    }
  }

  func clear() {
    queue.async { [self] in
      key = nil
      runtime = nil
      leased = false
    }
  }

  /// A barrier finishes any native compilation before deleting its model files
  /// or compiled cache. Awaiting this keeps the application main thread free.
  func discard(key discardedKey: String? = nil) async {
    await withCheckedContinuation { continuation in
      queue.async { [self] in
        if discardedKey == nil || key == discardedKey {
          key = nil
          runtime = nil
          leased = false
        }
        continuation.resume()
      }
    }
  }

  private func available(key requestedKey: String, load: () throws -> Runtime) throws -> Runtime {
    if key != requestedKey {
      key = requestedKey
      runtime = nil
      leased = false
    }
    if let runtime { return runtime }
    let value = try load()
    runtime = value
    return value
  }

  private enum CacheFailure: LocalizedError {
    case alreadyInUse
    var errorDescription: String? {
      "This depth model is already running. Stop 3D before restarting."
    }
  }
}
