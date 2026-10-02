import Foundation

/// Capture layouts supported by SR-Loom's MIT-licensed converter. Katanga's
/// Windows shared textures and raw Lytro files are separate source transports.
public enum StereoInputFormat: Int, CaseIterable, Codable, Sendable {
  case fullSBS, halfSBS, fullTAB, halfTAB, rowInterleaved, columnInterleaved
  case checkerboard, anaglyph, frameSequential, pulfrich, framePacking, quilt
  case vr180TAB, vr180SBS, vr360TAB, vr360SBS

  public var title: String {
    switch self {
    case .fullSBS: return "Side-by-Side (Full)"
    case .halfSBS: return "Side-by-Side (Half)"
    case .fullTAB: return "Top-and-Bottom (Full)"
    case .halfTAB: return "Top-and-Bottom (Half)"
    case .rowInterleaved: return "Row Interleaved"
    case .columnInterleaved: return "Column Interleaved"
    case .checkerboard: return "Checkerboard"
    case .anaglyph: return "Anaglyph"
    case .frameSequential: return "Frame Sequential (Experimental)"
    case .pulfrich: return "Pulfrich Effect"
    case .framePacking: return "Frame Packing (HDMI 1.4)"
    case .quilt: return "Quilt"
    case .vr180TAB: return "VR180 (Top-and-Bottom)"
    case .vr180SBS: return "VR180 (Side-by-Side)"
    case .vr360TAB: return "VR360 (Top-and-Bottom)"
    case .vr360SBS: return "VR360 (Side-by-Side)"
    }
  }
  public var isSBS: Bool { self == .fullSBS || self == .halfSBS }
  public var isVR: Bool { rawValue >= Self.vr180TAB.rawValue }
  var code: Int {
    switch self {
    case .fullSBS: return 11
    case .halfSBS: return 0
    case .fullTAB, .halfTAB: return 1
    case .anaglyph: return 2
    case .rowInterleaved: return 3
    case .columnInterleaved: return 4
    case .checkerboard: return 5
    case .pulfrich: return 6
    case .framePacking: return 7
    case .frameSequential: return 8
    case .quilt: return 9
    default: return 10
    }
  }
  var shader: String {
    switch self {
    case .fullSBS: return "PSFmtFullSBS"
    case .halfSBS: return "PSFmtHalfSBS"
    case .fullTAB, .halfTAB: return "PSFmtTAB"
    case .rowInterleaved: return "PSFmtRow"
    case .columnInterleaved: return "PSFmtColumn"
    case .checkerboard: return "PSFmtChecker"
    case .framePacking: return "PSFmtFramePack"
    case .anaglyph: return "PSFmtAnaglyph"
    default: return "PSMain"
    }
  }
}

public struct StereoInputSettings: Codable, Equatable, Sendable {
  public var format: StereoInputFormat = .fullSBS
  public var swapEyes = false
  public var anaglyphPair = 0, anaglyphMode = 4
  public var pulfrichND = false, affectedEye = 1, delayFrames = 1
  public var transmission = 0.3
  public var framePackingAlignment = 0.0
  public var quiltColumns = 5, quiltRows = 9, quiltLeft = 20, quiltRight = 24
  public var yaw = 0.0, pitch = 0.0, zoom = 1.0
  public init() {}
  public static let anaglyphPairs = [
    "Red / Cyan", "Red / Green", "Red / Blue", "Green / Magenta", "Amber / Blue", "Cyan / Magenta",
  ]
  public static let anaglyphModes = [
    "DeAnaglyph (Shared Colour)", "Filtered Colour", "Half Colour", "Monochrome",
    "Recovered Colour",
  ]
  public var validated: Self {
    var s = self
    func bound(_ v: Double, _ lo: Double, _ hi: Double, _ fallback: Double) -> Double {
      v.isFinite ? min(hi, max(lo, v)) : fallback
    }
    s.anaglyphPair = min(5, max(0, anaglyphPair))
    s.anaglyphMode = min(4, max(0, anaglyphMode))
    s.affectedEye = min(1, max(0, affectedEye))
    s.delayFrames = min(8, max(1, delayFrames))
    s.transmission = bound(transmission, 0.05, 1, 0.3)
    s.framePackingAlignment = bound(framePackingAlignment, -10, 10, 0)
    s.quiltColumns = min(16, max(1, quiltColumns))
    s.quiltRows = min(16, max(1, quiltRows))
    let last = s.quiltColumns * s.quiltRows - 1
    s.quiltLeft = min(last, max(0, quiltLeft))
    s.quiltRight = min(last, max(0, quiltRight))
    s.yaw = bound(yaw, -180, 180, 0)
    s.pitch = bound(pitch, -90, 90, 0)
    s.zoom = bound(zoom, 0.2, 3, 1)
    return s
  }
  public static func load(from defaults: UserDefaults = .standard) -> Self {
    if let data = defaults.data(forKey: "stereoInput"),
      let value = try? JSONDecoder().decode(Self.self, from: data)
    {
      return value.validated
    }
    var value = Self()
    if defaults.integer(forKey: "videoLayout") == 1 { value.format = .halfSBS }
    return value
  }
  public func save(to defaults: UserDefaults = .standard) {
    if let data = try? JSONEncoder().encode(validated) { defaults.set(data, forKey: "stereoInput") }
  }
}
