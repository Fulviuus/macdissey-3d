import Foundation

@main enum DepthInferenceWorkerChecks {
  static func main() async throws {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let completed = DispatchSemaphore(value: 0)
    let worker = DepthInferenceWorker<Int>(
      outputCount: 1, changedScene: { true },
      predict: { input, output in
        if input[0] == 1 {
          entered.signal()
          precondition(release.wait(timeout: .now() + 5) == .success)
        }
        output[0] = input[0]
      })
    worker.didComplete = { completed.signal() }
    precondition(worker.submit([1], frame: 100))
    precondition(entered.wait(timeout: .now() + 5) == .success)
    precondition(
      !worker.canSubmit && !worker.submit([2], frame: 200), "No queued inference backlog")
    let before = try worker.takeLatest()
    precondition(before == nil, "Reading depth remains nonblocking during prediction")
    release.signal()
    precondition(completed.wait(timeout: .now() + 5) == .success)
    precondition(
      !worker.canSubmit && !worker.submit([9], frame: 900),
      "An unconsumed frame/depth pair cannot be overwritten")
    let first = try worker.takeLatest()
    let consumed = try worker.takeLatest()
    precondition(
      first?.depth == [1] && first?.frame == 100 && first?.changedScene == true && consumed == nil,
      "Consume each completed map once")
    precondition(worker.submit([3], frame: 300))
    precondition(completed.wait(timeout: .now() + 5) == .success)
    let next = try worker.takeLatest()
    precondition(next?.depth == [3] && next?.frame == 300, "New input after completion")
    await worker.stop()
    precondition(!worker.canSubmit && !worker.submit([4], frame: 400), "Shutdown rejects work")
    enum Failure: Error { case expected }
    let failed = DepthInferenceWorker<Int>(outputCount: 1) { _, _ in throw Failure.expected }
    failed.didComplete = { completed.signal() }
    failed.submit([0], frame: 0)
    precondition(completed.wait(timeout: .now() + 5) == .success)
    do {
      _ = try failed.takeLatest()
      fatalError("Inference errors must propagate")
    } catch Failure.expected {}
    await failed.stop()
    try await checkRuntimeReuse()
    checkSceneChanges()
    await checkDelivery()
    print(
      "PASS nonblocking depth, bounded work, matched source-frame delivery, error propagation and shutdown"
    )
  }

  private final class Runtime {}
  static func checkRuntimeReuse() async throws {
    let cache = DepthRuntimeCache<Runtime>()
    let entered = DispatchSemaphore(value: 0)
    let finish = DispatchSemaphore(value: 0)
    let instance = Runtime()
    cache.prepare(key: "small") {
      entered.signal()
      precondition(finish.wait(timeout: .now() + 5) == .success)
      return instance
    }
    precondition(
      entered.wait(timeout: .now() + 5) == .success,
      "Preparation starts off the caller queue")
    let activation = Task.detached {
      try cache.acquire(key: "small") { fatalError("Activation must join existing preparation") }
    }
    finish.signal()
    let first = try await activation.value
    precondition(first === instance, "Activation uses the prepared native session")
    do {
      _ = try cache.acquire(key: "small") { Runtime() }
      fatalError("A live native session cannot be used by two converters")
    } catch {}
    cache.release(first)
    let second = try cache.acquire(key: "small") {
      fatalError("Reactivation must reuse the session")
    }
    precondition(second === first)
    cache.release(second)
    await cache.discard(key: "base")
    let retained = try cache.acquire(key: "small") {
      fatalError("Removing another model must not evict Small")
    }
    precondition(retained === first)
    cache.release(retained)
    await cache.discard(key: "small")
    let replacement = try cache.acquire(key: "small") { Runtime() }
    precondition(replacement !== first, "Removal must evict the prepared session")
    cache.release(replacement)
    await cache.discard()
    let compiling = DispatchSemaphore(value: 0)
    let finishCompilation = DispatchSemaphore(value: 0)
    let removalStarted = DispatchSemaphore(value: 0)
    let removed = DispatchSemaphore(value: 0)
    cache.prepare(key: "removing") {
      compiling.signal()
      precondition(finishCompilation.wait(timeout: .now() + 5) == .success)
      return Runtime()
    }
    precondition(compiling.wait(timeout: .now() + 5) == .success)
    let removal = Task {
      removalStarted.signal()
      await cache.discard(key: "removing")
      removed.signal()
    }
    precondition(removalStarted.wait(timeout: .now() + 5) == .success)
    precondition(
      removed.wait(timeout: .now()) == .timedOut,
      "Removal must wait for native compilation before deleting files")
    finishCompilation.signal()
    await removal.value
    enum Failure: Error { case expected }
    cache.prepare(key: "failed") { throw Failure.expected }
    let recovered = try cache.acquire(key: "failed") { Runtime() }
    cache.release(recovered)
    await cache.discard()
    print(
      "PASS background preparation, exclusive session reuse, model eviction and failed-preparation recovery"
    )
  }
}
