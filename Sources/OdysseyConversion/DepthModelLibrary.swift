import Foundation

@MainActor
public final class DepthModelLibrary {
  public static let shared = DepthModelLibrary()
  public private(set) var selected: DepthModel
  public private(set) var preparingSelection: DepthModel?
  public private(set) var preparationError: String?
  public var didChange: (() -> Void)?
  private let defaults: UserDefaults
  private let bundled: URL?
  private var preparesSelection = false
  private var preparationGeneration = 0

  public init(root: URL? = nil, defaults: UserDefaults = .standard, bundled: URL? = nil) {
    self.defaults = defaults
    self.bundled = bundled ?? Bundle.main.resourceURL?.appendingPathComponent("VideoDepthSmall")
    selected = DepthModel.load(defaults: defaults)
    // Previous versions downloaded models into this app-owned directory.
    // Both remaining models are bundled, so all old downloads are redundant.
    let downloads =
      root
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      .appendingPathComponent("macdissey 3d/DepthModels")
    if let entries = try? FileManager.default.contentsOfDirectory(
      at: downloads, includingPropertiesForKeys: nil)
    {
      let retired = Set(["da3Small", "da3Base", "v2Small", "v2Base", "videoSmall", "videoBase"])
      for entry in entries
      where retired.contains(entry.lastPathComponent)
        || entry.lastPathComponent.hasPrefix(".download-")
      {
        try? FileManager.default.removeItem(at: entry)
      }
    }
    if root == nil {
      let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("macdissey-3d/DepthModels/ort-1.30.0")
      try? FileManager.default.removeItem(at: cache)
    }
    if !isInstalled(selected) { selected = .samsung }
    selected.save(defaults: defaults)
  }
  public func isInstalled(_ model: DepthModel) -> Bool {
    guard model != .samsung else { return true }
    guard let bundled else { return false }
    return ["first.mlmodelc", "stream.mlmodelc"].allSatisfy { phase in
      let url = bundled.appendingPathComponent(phase)
      var directory: ObjCBool = false
      return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
        && directory.boolValue
        && FileManager.default.fileExists(atPath: url.appendingPathComponent("coremldata.bin").path)
    }
  }
  /// Warm both first-frame and recurrent paths without changing the display.
  public func prepareSelectedModel() {
    preparesSelection = true
    preparationGeneration += 1
    let generation = preparationGeneration
    preparingSelection = nil
    preparationError = nil
    if selected != .samsung, isInstalled(selected), let bundled {
      preparingSelection = selected
      VideoDepthPredictor.prepare(DepthModelConfiguration(model: selected, directory: bundled)) {
        [weak self] result in
        Task { @MainActor in
          guard let self, self.preparationGeneration == generation else { return }
          self.preparingSelection = nil
          if case .failure(let error) = result {
            self.preparationError = error.localizedDescription
          }
          self.didChange?()
        }
      }
    } else {
      VideoDepthPredictor.clearPrepared()
    }
    didChange?()
  }
  public func select(_ model: DepthModel) throws {
    guard isInstalled(model) else {
      throw GPUFailure("The bundled video depth model is missing. Reinstall the app.")
    }
    selected = model
    model.save(defaults: defaults)
    if preparesSelection { prepareSelectedModel() }
    didChange?()
  }
  public func configuration() throws -> DepthModelConfiguration? {
    guard selected != .samsung else { return nil }
    guard isInstalled(selected), let bundled else {
      selected = .samsung
      selected.save(defaults: defaults)
      didChange?()
      throw GPUFailure(
        "The bundled video depth model is missing. Samsung is selected; start conversion again.")
    }
    return DepthModelConfiguration(model: selected, directory: bundled)
  }
}
