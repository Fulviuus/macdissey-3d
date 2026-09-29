import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable {
  let keyCode: UInt32
  let modifiers: UInt32
  let keyLabel: String

  static let standard = KeyboardShortcut(
    keyCode: UInt32(kVK_ANSI_3),
    modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "3")
  static let defaultsKey = "activationShortcut"
  static let allowedModifiers = UInt32(controlKey | optionKey | cmdKey | shiftKey)

  var isValid: Bool {
    keyCode < 128 && keyCode != UInt32(kVK_Escape)
      && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
      && modifiers & ~Self.allowedModifiers == 0
      && modifiers & UInt32(controlKey | optionKey | cmdKey) != 0 && !keyLabel.isEmpty
      && keyLabel.count <= 24
  }

  var displayName: String {
    var parts: [String] = []
    if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
    if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
    if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
    if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
    return parts.joined() + keyLabel
  }

  init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.keyLabel = keyLabel
  }

  init?(event: NSEvent) {
    let flags = event.modifierFlags
    var modifiers: UInt32 = 0
    if flags.contains(.control) { modifiers |= UInt32(controlKey) }
    if flags.contains(.option) { modifiers |= UInt32(optionKey) }
    if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
    if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
    let special: [UInt16: String] = [
      36: "Return", 48: "Tab", 49: "Space", 51: "Delete",
      76: "Enter", 117: "Forward Delete", 123: "←", 124: "→", 125: "↓", 126: "↑",
      115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
      122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
      98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
      105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
      80: "F19", 90: "F20",
    ]
    guard let label = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased(),
      !label.isEmpty
    else { return nil }
    self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    guard isValid else { return nil }
  }

  static func load(from defaults: UserDefaults = .standard) -> Self {
    guard let data = defaults.data(forKey: defaultsKey),
      let shortcut = try? JSONDecoder().decode(Self.self, from: data), shortcut.isValid
    else { return .standard }
    return shortcut
  }

  func save(to defaults: UserDefaults = .standard) {
    guard isValid, let data = try? JSONEncoder().encode(self) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }
}
