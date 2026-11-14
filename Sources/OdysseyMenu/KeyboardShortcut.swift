import AppKit
import Carbon

/// One shared modifier family; action keys stay fixed and cannot collide.
struct ShortcutModifiers: Codable, Equatable {
  let rawValue: UInt32

  static let standard = Self(rawValue: UInt32(controlKey | optionKey | cmdKey))
  static let defaultsKey = "shortcutModifiers"
  static let allowed = UInt32(controlKey | optionKey | cmdKey | shiftKey)
  static let choices: [(title: String, flag: UInt32)] = [
    ("Control", UInt32(controlKey)), ("Option", UInt32(optionKey)),
    ("Command", UInt32(cmdKey)), ("Shift", UInt32(shiftKey)),
  ]

  var isValid: Bool {
    rawValue & ~Self.allowed == 0 && rawValue & UInt32(controlKey | optionKey | cmdKey) != 0
  }

  var displayName: String {
    var text = ""
    for (flag, glyph) in [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")] {
      if rawValue & UInt32(flag) != 0 { text += glyph }
    }
    return text
  }

  func displayName(for action: ShortcutAction) -> String { displayName + action.keyLabel }

  static func load(from defaults: UserDefaults = .standard) -> Self {
    if defaults.object(forKey: defaultsKey) != nil {
      guard let data = defaults.data(forKey: defaultsKey),
        let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid
      else { return .standard }
      return value
    }
    // Keep a user's previous modifier choice when moving from the single
    // activation shortcut to a family. The action suffix is now always 3.
    if let data = defaults.data(forKey: "activationShortcut"),
      let legacy = try? JSONDecoder().decode(LegacyShortcut.self, from: data), legacy.isValid
    {
      return Self(rawValue: legacy.modifiers)
    }
    return .standard
  }

  func save(to defaults: UserDefaults = .standard) {
    guard isValid, let data = try? JSONEncoder().encode(self) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }

  private struct LegacyShortcut: Decodable {
    let keyCode: UInt32, modifiers: UInt32
    let keyLabel: String
    var isValid: Bool {
      keyCode < 128 && keyCode != UInt32(kVK_Escape)
        && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
        && ShortcutModifiers(rawValue: modifiers).isValid
        && !keyLabel.isEmpty && keyLabel.count <= 24
    }
  }
}

struct ShortcutModifiersError: LocalizedError {
  var errorDescription: String? { "Include at least Control, Option or Command in app shortcuts." }
}

enum ShortcutAction: CaseIterable {
  case stereo, conversion, exit, showValues, decreaseDepth, increaseDepth, decreasePopOut,
    increasePopOut

  var keyCode: UInt32 {
    let code =
      switch self {
      case .stereo: kVK_ANSI_3
      case .conversion: kVK_ANSI_2
      case .exit: kVK_Escape
      case .showValues: kVK_ANSI_1
      case .decreaseDepth: kVK_ANSI_4
      case .increaseDepth: kVK_ANSI_5
      case .decreasePopOut: kVK_ANSI_6
      case .increasePopOut: kVK_ANSI_7
      }
    return UInt32(code)
  }

  var keyLabel: String {
    switch self {
    case .stereo: "3"
    case .conversion: "2"
    case .exit: "Esc"
    case .showValues: "1"
    case .decreaseDepth: "4"
    case .increaseDepth: "5"
    case .decreasePopOut: "6"
    case .increasePopOut: "7"
    }
  }

  var title: String {
    switch self {
    case .stereo: "Start stereo video / stop 3D"
    case .conversion: "Start conversion / stop 3D"
    case .exit: "Stop any 3D mode"
    case .showValues: "Show Depth and Pop-Out values"
    case .decreaseDepth: "Decrease 3D Depth"
    case .increaseDepth: "Increase 3D Depth"
    case .decreasePopOut: "Decrease Pop-Out"
    case .increasePopOut: "Increase Pop-Out"
    }
  }

  var adjustment: (depth: Int, popOut: Int)? {
    switch self {
    case .showValues: (0, 0)
    case .decreaseDepth: (-1, 0)
    case .increaseDepth: (1, 0)
    case .decreasePopOut: (0, -1)
    case .increasePopOut: (0, 1)
    default: nil
    }
  }
}
