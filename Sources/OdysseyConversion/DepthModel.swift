import Foundation

/// Both choices ship with the application. Retired preferences use Samsung.
public enum DepthModel: String, CaseIterable, Codable, Sendable {
  case samsung, videoSmall

  public var title: String {
    switch self {
    case .samsung: return "Samsung · Default"
    case .videoSmall: return "Video Depth Anything Small"
    }
  }

  public var detail: String {
    switch self {
    case .samsung: return "The original fast conversion model."
    case .videoSmall: return "Uses frame history for steadier video depth."
    }
  }

  public static let preferenceKey = "conversionDepthModel"
  public static func load(defaults: UserDefaults = .standard) -> Self {
    Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .samsung
  }
  public func save(defaults: UserDefaults = .standard) {
    defaults.set(rawValue, forKey: Self.preferenceKey)
  }
}

public struct DepthModelConfiguration: Sendable {
  public let model: DepthModel
  public let directory: URL
  public init(model: DepthModel, directory: URL) {
    self.model = model
    self.directory = directory
  }
}
