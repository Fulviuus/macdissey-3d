import AppKit

@main
enum MacdisseyMain {
  @MainActor static func main() {
    if OutputWatchdog.runIfRequested() { return }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    if CommandLine.arguments.contains("--screen-capture-check") {
      Task { @MainActor in
        do {
          try await ScreenCaptureAccess.check()
          print("PASS: ScreenCaptureKit access authorized")
          fflush(stdout)
          NSApp.terminate(nil)
        } catch {
          fputs("ScreenCaptureKit access failed: \(error)\n", stderr)
          exit(1)
        }
      }
      app.run()
      return
    }
    if CommandLine.arguments.contains("--integration-smoke-test")
      || CommandLine.arguments.contains("--desktop-smoke-test")
      || CommandLine.arguments.contains("--conversion-smoke-test")
    {
      Task { @MainActor in
        let session = ThreeDSession()
        session.allowsLensActivation = false
        if CommandLine.arguments.contains("--desktop-smoke-test") { session.mode = .desktop }
        if CommandLine.arguments.contains("--conversion-smoke-test") { session.mode = .conversion }
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
          let duration =
            CommandLine.arguments.contains("--extended-check")
            ? 60 : (session.mode == .video ? 2 : 5)
          for _ in 0..<duration {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let failure { throw failure }
            guard session.outputDisplayIsUnchanged else {
              throw AppError.unavailable("Output display changed during integration check")
            }
          }
          let frames = session.renderedFrames
          let conversions = session.convertedFrames
          await session.stop()
          if let failure { throw failure }
          guard frames > 0 else { throw AppError.unavailable("No frames rendered") }
          if session.mode == .conversion {
            guard conversions > 0 else { throw AppError.unavailable("No converted frames") }
            print("Converted \(conversions) captured frames in \(duration) seconds.")
          }
          print(
            "PASS: \(session.mode), native 4K output, original GLSL, camera pipeline, \(frames) presented frames, shutdown and mode restoration. Lenses kept off."
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
