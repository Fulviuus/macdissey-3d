@main enum OdysseyDisplayChecks {
  static func main() {
    for model: UInt32 in [0x7860, 0x7859] {
      precondition(
        OdysseyDisplay.matches(vendor: 0x4c2d, model: model),
        "Both reported G90XF display models must be recognized")
      for vendor: UInt32 in [0, 0x04e8, 0x4c2c, 0x4c2e, UInt32.max] {
        precondition(
          !OdysseyDisplay.matches(vendor: vendor, model: model),
          "A supported model number must still require Samsung's display vendor ID")
      }
    }
    for model: UInt32 in [0, 0x7858, 0x785a, 0x785f, 0x7861, UInt32.max] {
      precondition(
        !OdysseyDisplay.matches(vendor: 0x4c2d, model: model),
        "Unrecognized Samsung displays must remain excluded")
    }
    print(
      "PASS G90XF display matching: both model variants, vendor validation and unrelated displays")
  }
}
