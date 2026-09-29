import AppKit
import Carbon

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  precondition(condition(), message)
  checks += 1
}

_ = NSApplication.shared
let suite = "local.odyssey3d.settings-checks.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
check(
  KeyboardShortcut.load(from: defaults) == .standard,
  "Missing preference must keep the existing shortcut")
check(KeyboardShortcut.standard.displayName == "⌃⌥⌘3", "Default shortcut display is incorrect")
defaults.set(Data("invalid".utf8), forKey: KeyboardShortcut.defaultsKey)
check(KeyboardShortcut.load(from: defaults) == .standard, "Corrupt preference must recover")

let other = KeyboardShortcut(
  keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(controlKey | optionKey), keyLabel: "4")
other.save(to: defaults)
check(
  KeyboardShortcut.load(from: defaults) == other,
  "Edited shortcut did not survive preference reload")
for invalid in [
  KeyboardShortcut(keyCode: 53, modifiers: UInt32(cmdKey), keyLabel: "Esc"),
  KeyboardShortcut(keyCode: 55, modifiers: UInt32(cmdKey), keyLabel: "Command"),
  KeyboardShortcut(keyCode: 21, modifiers: 0, keyLabel: "4"),
  KeyboardShortcut(keyCode: 21, modifiers: UInt32(shiftKey), keyLabel: "$"),
  KeyboardShortcut(keyCode: 9999, modifiers: UInt32(cmdKey), keyLabel: "4"),
  KeyboardShortcut(keyCode: 21, modifiers: UInt32(cmdKey) | 1, keyLabel: "4"),
] {
  check(!invalid.isValid, "Unsafe shortcut accepted")
  defaults.set(try JSONEncoder().encode(invalid), forKey: KeyboardShortcut.defaultsKey)
  check(KeyboardShortcut.load(from: defaults) == .standard, "Invalid stored shortcut must recover")
}
func event(code: UInt16, flags: NSEvent.ModifierFlags, characters: String) -> NSEvent {
  NSEvent.keyEvent(
    with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
    windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
    isARepeat: false, keyCode: code)!
}
check(
  KeyboardShortcut(event: event(code: 21, flags: [.control, .option], characters: "4")) == other,
  "Recorder modifier conversion differs from registration")
check(
  KeyboardShortcut(event: event(code: 123, flags: [.command], characters: ""))?.displayName == "⌘←",
  "Recorder must name navigation keys")
check(
  KeyboardShortcut(event: event(code: 21, flags: [.shift], characters: "$")) == nil,
  "Typing alone must not become a global shortcut")

// Exercise real Carbon ownership: a failed replacement must leave the old
// binding registered, then release must allow the same combination again.
let key = UInt32(kVK_F19)
let modifiers = UInt32(controlKey | optionKey | cmdKey)
var original: HotKey? = try HotKey(keyCode: key, modifiers: modifiers, id: 9001, action: {})
do {
  _ = try HotKey(keyCode: key, modifiers: modifiers, id: 9002, action: {})
  fatalError("Duplicate hotkey registration should fail")
} catch is HotKeyError { checks += 1 }
check(original != nil, "Failed replacement discarded the original")
original = nil
let replacement = try HotKey(keyCode: key, modifiers: modifiers, id: 9003, action: {})
withExtendedLifetime(replacement) { checks += 1 }
print("PASS: \(checks) shortcut persistence, validation, capture and Carbon ownership checks")
