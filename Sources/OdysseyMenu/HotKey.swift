import Carbon

final class HotKey {
  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private let action: () -> Void

  init(keyCode: UInt32, modifiers: UInt32, id: UInt32, action: @escaping () -> Void) throws {
    self.action = action
    var type = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let context, let event else { return OSStatus(eventNotHandledErr) }
        var key = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
        let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
        guard key.signature == 0x4f44_5359, key.id == hotKey.id else {
          return OSStatus(eventNotHandledErr)
        }
        hotKey.action()
        return noErr
      }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    guard status == noErr else { throw HotKeyError(status: status) }
    self.id = id
    let result = RegisterEventHotKey(
      keyCode, modifiers,
      EventHotKeyID(signature: 0x4f44_5359, id: id), GetApplicationEventTarget(), 0, &hotKey)
    guard result == noErr else {
      if let handler {
        RemoveEventHandler(handler)
        self.handler = nil
      }
      throw HotKeyError(status: result)
    }
  }

  private var id: UInt32 = 0
  deinit {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    if let handler { RemoveEventHandler(handler) }
  }
}

struct HotKeyError: LocalizedError {
  let status: OSStatus
  var errorDescription: String? {
    "This shortcut is unavailable. Choose another combination. You can activate 3D from the menu."
  }
}
