import AppKit
import IOKit

struct USBDevice: Codable {
  let vendorID: Int
  let productID: Int
  let name: String
  let serialPort: String?
}

enum Hardware {
  static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue()
  }

  static func lensSerialPort(_ entry: io_registry_entry_t) -> String? {
    var iterator: io_iterator_t = 0
    guard
      IORegistryEntryCreateIterator(
        entry, kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS
    else { return nil }
    defer { IOObjectRelease(iterator) }
    while case let child = IOIteratorNext(iterator), child != 0 {
      let path = property(child, "IOCalloutDevice") as? String
      IOObjectRelease(child)
      if let path { return path }
    }
    return nil
  }

  static func devices() -> [USBDevice] {
    var iterator: io_iterator_t = 0
    guard
      IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS
    else { return [] }
    defer { IOObjectRelease(iterator) }
    var devices: [USBDevice] = []
    while case let entry = IOIteratorNext(iterator), entry != 0 {
      defer { IOObjectRelease(entry) }
      let vendor = (property(entry, "idVendor") as? NSNumber)?.intValue ?? 0
      let product = (property(entry, "idProduct") as? NSNumber)?.intValue ?? 0
      guard
        (vendor == 0x354b && product == 0x0116) || (vendor == 0x04e8 && product == 0x20d7)
          || (vendor == 0x1b20 && product == 0x0300)
      else { continue }
      devices.append(
        USBDevice(
          vendorID: vendor, productID: product,
          name: property(entry, "USB Product Name") as? String ?? "Monitor control interface",
          serialPort: vendor == 0x354b ? lensSerialPort(entry) : nil))
    }
    return devices
  }

  static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
      ?? 0
  }

  static func isOdyssey(_ screen: NSScreen) -> Bool {
    let id = displayID(screen)
    return CGDisplayVendorNumber(id) == 0x4c2d && CGDisplayModelNumber(id) == 0x7860
  }

}
