import AppKit
import Carbon

@main enum AppSettingsChecks {
  @MainActor static func main() throws {
    var checks = 0
    func check(_ condition: Bool, _ message: String) {
      precondition(condition, message)
      checks += 1
    }

    _ = NSApplication.shared
    let suite = "local.odyssey3d.settings-checks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    check(
      ShortcutModifiers.load(from: defaults) == .standard, "Missing preference uses shared defaults"
    )
    let standard = ShortcutModifiers.standard
    let expected: [ShortcutAction: String] = [
      .stereo: "⌃⌥⌘3", .conversion: "⌃⌥⌘2", .exit: "⌃⌥⌘Esc", .showValues: "⌃⌥⌘1",
      .decreaseDepth: "⌃⌥⌘4", .increaseDepth: "⌃⌥⌘5", .decreasePopOut: "⌃⌥⌘6",
      .increasePopOut: "⌃⌥⌘7",
    ]
    for action in ShortcutAction.allCases {
      check(
        standard.displayName(for: action) == expected[action], "Default action shortcut differs")
    }
    check(Set(ShortcutAction.allCases.map(\.keyCode)).count == 8, "Each action needs a unique key")
    let custom = ShortcutModifiers(rawValue: UInt32(controlKey | cmdKey))
    let legacy: [String: Any] = [
      "keyCode": kVK_ANSI_4, "modifiers": custom.rawValue, "keyLabel": "4",
    ]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "activationShortcut")
    check(ShortcutModifiers.load(from: defaults) == custom, "Keep previous custom modifiers")
    check(
      ShortcutModifiers.load(from: defaults).displayName(for: .stereo) == "⌃⌘3",
      "Migrate the family without keeping an old individual action key")
    standard.save(to: defaults)
    check(ShortcutModifiers.load(from: defaults) == standard, "New preference overrides legacy")
    custom.save(to: defaults)
    check(ShortcutModifiers.load(from: defaults) == custom, "Shared modifiers persist")
    for rawValue in [UInt32(0), UInt32(shiftKey), UInt32(cmdKey) | 1, UInt32.max] {
      let invalid = ShortcutModifiers(rawValue: rawValue)
      check(!invalid.isValid, "Do not permit plain Escape or unsupported modifiers")
      defaults.set(try JSONEncoder().encode(invalid), forKey: ShortcutModifiers.defaultsKey)
      check(ShortcutModifiers.load(from: defaults) == standard, "Invalid stored modifiers recover")
      invalid.save(to: defaults)
    }
    defaults.set(Data("invalid".utf8), forKey: ShortcutModifiers.defaultsKey)
    check(ShortcutModifiers.load(from: defaults) == standard, "Corrupt family preference recovers")

    func canRegister(_ action: ShortcutAction, modifiers: ShortcutModifiers) -> Bool {
      do {
        let probe = try HotKey(
          keyCode: action.keyCode, modifiers: modifiers.rawValue, id: 9000, action: {})
        withExtendedLifetime(probe) {}
        return true
      } catch is HotKeyError { return false } catch {
        preconditionFailure("Unexpected registration error: \(error)")
      }
    }

    // These checks exercise real Carbon ownership in this process. Non-exclusive
    // registration permits the user's running app to retain its own shortcuts.
    let family = try AppHotKeys(modifiers: standard, perform: { _ in })
    check(!canRegister(.stereo, modifiers: standard), "Register stereo globally")
    check(!canRegister(.conversion, modifiers: standard), "Register conversion globally")
    check(canRegister(.exit, modifiers: standard), "Idle exit must not capture keys")
    check(
      canRegister(.decreaseDepth, modifiers: standard), "Idle adjustments must not capture keys")
    try family.setContext(.active)
    check(!canRegister(.exit, modifiers: standard), "Every active mode has modified Escape")
    check(
      canRegister(.showValues, modifiers: standard), "Video does not capture conversion controls")
    try family.setContext(.conversion)
    for action in ShortcutAction.allCases {
      check(!canRegister(action, modifiers: standard), "Conversion must register every action")
    }
    check(
      canRegister(.exit, modifiers: ShortcutModifiers(rawValue: 0)),
      "Plain Escape must remain unregistered while conversion is active")
    do {
      try family.setModifiers(ShortcutModifiers(rawValue: 0))
      preconditionFailure("A family without modifiers must never be installed")
    } catch is ShortcutModifiersError { checks += 1 }
    check(
      family.modifiers == standard && family.context == .conversion,
      "Invalid modifiers preserve every active shortcut")
    try family.setModifiers(custom)
    for action in ShortcutAction.allCases {
      check(!canRegister(action, modifiers: custom), "All actions must move to the new modifiers")
      check(canRegister(action, modifiers: standard), "Release every old modifier binding")
    }
    check(family.modifiers == custom && family.context == .conversion, "Retain session context")
    try family.setModifiers(custom)  // A repeated save must reuse its own registrations.
    try family.setContext(.idle)
    check(canRegister(.exit, modifiers: custom), "Stopping releases modified Escape")
    check(canRegister(.showValues, modifiers: custom), "Stopping releases conversion controls")

    // Force failure after the first replacement registration. The original family
    // and context must survive, and the partial new family must be released.
    var blocker: HotKey? = try HotKey(
      keyCode: ShortcutAction.conversion.keyCode, modifiers: standard.rawValue, id: 9001, action: {}
    )
    do {
      try family.setModifiers(standard)
      preconditionFailure("A conflicting binding must fail the family update")
    } catch is HotKeyError { checks += 1 }
    check(blocker != nil, "Retain the conflicting registration through the failed update")
    check(family.modifiers == custom && family.context == .idle, "Failed update preserves state")
    check(!canRegister(.stereo, modifiers: custom), "Failed update retains old stereo")
    check(!canRegister(.conversion, modifiers: custom), "Failed update retains old conversion")
    check(canRegister(.stereo, modifiers: standard), "Failed update releases partial replacement")
    blocker = nil
    try family.setModifiers(standard)
    check(family.modifiers == standard, "Retry succeeds after the conflict is removed")

    blocker = try HotKey(
      keyCode: ShortcutAction.showValues.keyCode, modifiers: standard.rawValue, id: 9002, action: {}
    )
    do {
      try family.setContext(.conversion)
      preconditionFailure("A conflicting session key must fail startup")
    } catch is HotKeyError { checks += 1 }
    check(blocker != nil, "Retain the conflicting registration through failed startup")
    check(family.context == .idle, "Failed session registration leaves the app idle")
    check(canRegister(.exit, modifiers: standard), "Failed startup releases the temporary exit key")
    blocker = nil
    try family.setContext(.conversion)
    try family.setContext(.idle)

    // Check dispatch through the actual Carbon event target without sending a
    // physical keypress to any app or activating the connected monitor.
    var delivered = 0
    let dispatch = try HotKey(
      keyCode: UInt32(kVK_F19), modifiers: standard.rawValue, id: 9010, action: { delivered += 1 })
    var event: EventRef?
    check(
      CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event)
        == noErr,
      "Create a local hotkey event")
    var identifier = EventHotKeyID(signature: 0x4f44_5359, id: 9010)
    check(
      SetEventParameter(
        event!, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        MemoryLayout<EventHotKeyID>.size, &identifier) == noErr,
      "Set local hotkey identity")
    withExtendedLifetime(dispatch) {
      check(
        SendEventToEventTarget(event!, GetApplicationEventTarget()) == noErr, "Dispatch the hotkey")
    }
    ReleaseEvent(event!)
    check(delivered == 1, "Route an event to exactly its matching action")
    print(
      "PASS: \(checks) shared shortcut, migration, context, rollback and Carbon dispatch checks")

  }
}
