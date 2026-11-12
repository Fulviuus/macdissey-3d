enum SBSLayout: Int, CaseIterable {
  case fullWidth, halfWidth

  var title: String {
    self == .fullWidth ? "Remove black bars" : "Stretch to fill"
  }

  var help: String {
    self == .fullWidth
      ? "Crop the top and bottom bars before filling the screen."
      : "Stretch each complete eye view to fill the screen."
  }
}
