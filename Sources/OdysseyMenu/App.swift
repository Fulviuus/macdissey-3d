import AppKit

@main
enum MacdisseyMain {
  @MainActor static func main() {
    if OutputWatchdog.runIfRequested() { return }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    if CommandLine.arguments.contains("--integration-smoke-test") {
      Task { @MainActor in
        let session = ThreeDSession()
        session.allowsLensActivation = false
        var failure: Error?
        session.failure = { failure = $0 }
        do {
          guard let screen = NSScreen.screens.first(where: Hardware.isOdyssey),
            let port = Hardware.devices().first(where: { $0.vendorID == 0x354b })?.serialPort
          else {
            throw AppError.unavailable("Monitor unavailable")
          }
          let profile = try await Task.detached { try FactoryProfile.retrieve(port: port) }.value
          try await session.start(on: screen, profile: profile)
          try await Task.sleep(nanoseconds: 2_000_000_000)
          let frames = session.renderedFrames
          await session.stop()
          if let failure { throw failure }
          guard frames > 0 else { throw AppError.unavailable("No frames rendered") }
          print(
            "PASS: native 4K capture, original GLSL, camera pipeline, \(frames) presented frames, shutdown and mode restoration. Lenses kept off."
          )
          fflush(stdout)
          NSApp.terminate(nil)
        } catch {
          await session.stop()
          fputs("Integration failed: \(error)\n", stderr)
          fflush(stderr)
          exit(1)
        }
      }
      app.run()
      return
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
