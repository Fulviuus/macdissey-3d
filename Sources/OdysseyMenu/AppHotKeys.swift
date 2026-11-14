import Foundation

/// Rebind a whole shortcut family atomically. Session-only commands release
/// their registrations when idle, and plain Escape is never registered.
@MainActor final class AppHotKeys {
  enum Context {
    case idle, active, conversion

    var actions: [ShortcutAction] {
      switch self {
      case .idle: [.stereo, .conversion]
      case .active: [.stereo, .conversion, .exit]
      case .conversion: ShortcutAction.allCases
      }
    }
  }

  private(set) var modifiers: ShortcutModifiers
  private(set) var context: Context = .idle
  private var bindings: [ShortcutAction: HotKey] = [:]
  private var nextID: UInt32 = 1000
  private let perform: (ShortcutAction) -> Void

  init(
    modifiers: ShortcutModifiers, context: Context = .idle,
    perform: @escaping (ShortcutAction) -> Void
  ) throws {
    self.modifiers = modifiers
    self.perform = perform
    try replace(modifiers: modifiers, context: context)
  }

  func setModifiers(_ value: ShortcutModifiers) throws {
    try replace(modifiers: value, context: context)
  }

  func setContext(_ value: Context) throws {
    try replace(modifiers: modifiers, context: value)
  }

  private func replace(modifiers value: ShortcutModifiers, context newContext: Context) throws {
    guard value.isValid else { throw ShortcutModifiersError() }
    var replacement: [ShortcutAction: HotKey] = [:]
    for action in newContext.actions {
      if value == modifiers, let existing = bindings[action] {
        replacement[action] = existing
      } else {
        nextID &+= 1
        replacement[action] = try HotKey(
          keyCode: action.keyCode, modifiers: value.rawValue, id: nextID
        ) { [weak self] in self?.perform(action) }
      }
    }
    // Nothing persistent changes until every new registration succeeds. A
    // failure releases the partial replacement and preserves the old family.
    bindings = replacement
    modifiers = value
    context = newContext
  }
}
