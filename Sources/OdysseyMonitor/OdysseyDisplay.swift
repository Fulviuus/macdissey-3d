/// Known display product IDs for the Samsung Odyssey 3D G90XF.
/// These are display identifiers, separate from the monitor's USB vendor IDs.
public enum OdysseyDisplay {
  public static func matches(vendor: UInt32, model: UInt32) -> Bool {
    vendor == 0x4c2d && (model == 0x7860 || model == 0x7859)
  }
}
