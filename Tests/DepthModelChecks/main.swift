import Foundation
import OdysseyConversion

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else { fatalError(message) }
}

@main enum DepthModelChecks {
  @MainActor static func main() async throws {
    setbuf(stdout, nil)
    let suite = "DepthModelChecks-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let bundled = root.appendingPathComponent("bundle")
    for phase in ["first", "stream"] {
      let folder = bundled.appendingPathComponent(phase + ".mlmodelc")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try Data([1]).write(to: folder.appendingPathComponent("coremldata.bin"))
    }
    defaults.set("videoBase", forKey: DepthModel.preferenceKey)
    for name in [
      "da3Small", "da3Base", "v2Small", "v2Base", "videoBase", "videoSmall", ".download-abandoned",
    ] {
      let folder = root.appendingPathComponent(name)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try Data([1]).write(to: folder.appendingPathComponent("old-model"))
    }
    let unrelated = root.appendingPathComponent("keep-this-file")
    try Data([2]).write(to: unrelated)
    let library = DepthModelLibrary(root: root, defaults: defaults, bundled: bundled)
    require(library.selected == .samsung, "Samsung is the initial default and replaces Base")
    require(DepthModel.allCases == [.samsung, .videoSmall], "Only Samsung and Small remain")
    require(
      defaults.string(forKey: DepthModel.preferenceKey) == "samsung", "Retired selection reset")
    let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
    require(
      Set(remaining) == Set(["bundle", "keep-this-file"]),
      "Only app-owned redundant downloads removed")
    require(library.isInstalled(.videoSmall), "Small is available directly from the bundle")
    let initial = try library.configuration()
    require(initial == nil, "Samsung uses the original conversion configuration")
    try library.select(.videoSmall)
    let configuration = try library.configuration()
    require(configuration?.directory == bundled, "Small uses bundled compiled assets")
    let reopened = DepthModelLibrary(root: root, defaults: defaults, bundled: bundled)
    require(reopened.selected == .videoSmall, "Small selection persists")
    try FileManager.default.removeItem(at: bundled.appendingPathComponent("stream.mlmodelc"))
    let missing = DepthModelLibrary(root: root, defaults: defaults, bundled: bundled)
    require(missing.selected == .samsung, "Missing bundled model resets safely")
    do {
      try library.select(.videoSmall)
      fatalError("Incomplete model must not be selectable")
    } catch {}
    do {
      _ = try library.configuration()
      fatalError("Missing selected model must report an error")
    } catch {}
    require(library.selected == .samsung, "Deleted selected model returns to Samsung")
    print(
      "PASS bundled model selection, Base migration, redundant download cleanup and missing-file fallback"
    )
    guard let path = ProcessInfo.processInfo.environment["MACDISSEY_DEPTH_CHECK_DIRECTORY"] else {
      print("SKIP Core ML model inference: compiled public fixture not supplied")
      return
    }
    try predict(DepthModelConfiguration(model: .videoSmall, directory: URL(fileURLWithPath: path)))
  }

  static func predict(_ configuration: DepthModelConfiguration) throws {
    let start = Date()
    let predictor = try VideoDepthPredictor(configuration)
    print("Loaded bundled Core ML models in \(Date().timeIntervalSince(start))s")
    let count = 518 * 294
    var input = (0..<(count * 3)).map { Float($0 % 251) / 125 - 1 }
    let firstInput = input
    var firstOutput: [Float] = []
    var output = [Float](repeating: 0, count: count)
    var durations: [Double] = []
    for frame in 0..<46 {
      if frame > 0 { input = input.map { $0 * 0.9 } }
      let start = Date()
      try predictor.predict(input, output: &output)
      durations.append(Date().timeIntervalSince(start))
      if frame == 0 { firstOutput = output }
      require(output.allSatisfy(\.isFinite), "Finite depth")
      require((output.max()! - output.min()!) > 0.00001, "Non-degenerate depth")
      if [0, 1, 2, 45].contains(frame),
        let path = ProcessInfo.processInfo.environment["MACDISSEY_DEPTH_CHECK_OUTPUT"]
      {
        try output.withUnsafeBytes { Data($0) }.write(
          to: URL(fileURLWithPath: path).appendingPathComponent("coreml-small-\(frame).f32"))
      }
    }
    predictor.reset()
    try predictor.predict(firstInput, output: &output)
    let maxDelta = zip(output, firstOutput).map { abs($0 - $1) }.max()!
    require(maxDelta < 0.005, "Reactivation clears history and reproduces the first depth map")
    // A distinct next shot must behave exactly like a newly activated model,
    // despite retaining more than a full window of the previous shot above.
    let newShot = [Float](repeating: 2, count: count * 3)
    try predictor.predict(newShot, output: &output)
    require(predictor.changedScene, "Scene cut resets recurrent context before inference")
    let cutOutput = output
    predictor.reset()
    try predictor.predict(newShot, output: &output)
    let cutDelta = zip(output, cutOutput).map { abs($0 - $1) }.max()!
    require(cutDelta < 0.005, "A scene cut matches the same shot in a fresh model")
    try predictor.predict(newShot, output: &output)
    require(!predictor.changedScene, "The following frame retains the new shot context")
    print("PASS Core ML scene cut matches fresh first frame; maximum delta \(cutDelta)")
    let sorted = durations.dropFirst(5).sorted()
    print(
      "PASS 46-frame Core ML streaming, retention boundary and history reset; median \(sorted[sorted.count / 2] * 1000)ms, p95 \(sorted[Int(Double(sorted.count - 1) * 0.95)] * 1000)ms, reset delta \(maxDelta)"
    )
  }
}
