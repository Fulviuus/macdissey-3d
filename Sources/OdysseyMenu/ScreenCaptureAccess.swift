import ScreenCaptureKit

enum ScreenCaptureAccess {
  static func check() async throws {
    do {
      // Ask the API we actually use. A legacy CoreGraphics preflight can
      // reject access before ScreenCaptureKit has a chance to authorize it.
      _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch let error as NSError {
      guard error.domain == SCStreamErrorDomain,
        error.code == SCStreamError.Code.userDeclined.rawValue
      else { throw error }
      throw AppError.unavailable(
        "Allow macdissey 3d in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen the app. If it is already enabled after an app update, remove its entry with the minus button and add this copy of the app again."
      )
    }
  }
}
