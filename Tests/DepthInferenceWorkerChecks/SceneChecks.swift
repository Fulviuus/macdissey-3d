import Foundation

func checkSceneChanges() {
  let width = 64
  let height = 36
  let pixels = width * height
  let mean: [Float] = [0.485, 0.456, 0.406]
  let std: [Float] = [0.229, 0.224, 0.225]
  func image(_ phase: Int, alternate: Bool = false) -> [Float] {
    var result = [Float](repeating: 0, count: pixels * 3)
    for y in 0..<height {
      for x in 0..<width {
        for c in 0..<3 {
          // Moving edge changes position without changing the background shot.
          let square = ((x + phase) % width) < 16 && y > 12 && y < 24
          let rgb: Float = alternate ? (square ? 0.95 : 0.8) : (square ? 0.45 : 0.1)
          result[c * pixels + y * width + x] = (rgb - mean[c]) / std[c]
        }
      }
    }
    return result
  }
  var scene = VideoSceneDetector()
  precondition(
    scene.changed(image(0), width: width, height: height), "First shot initializes history")
  precondition(
    !scene.changed(image(0), width: width, height: height), "Repeated frame keeps history")
  for phase in 1..<50 {
    precondition(
      !scene.changed(image(phase), width: width, height: height), "Motion keeps temporal context")
  }
  precondition(
    scene.changed(image(50, alternate: true), width: width, height: height),
    "Abrupt cut discards the old shot")
  precondition(
    !scene.changed(image(51, alternate: true), width: width, height: height),
    "New shot stabilizes immediately")
  scene.reset()
  precondition(
    scene.changed(image(51, alternate: true), width: width, height: height),
    "New activation starts without scene history")
  print("PASS shot detection: motion retains context, cuts and reactivation reset it")
}

func checkDelivery() async {
  let delivery = ConversionFrameDelivery<Int>()
  let entered = DispatchSemaphore(value: 0)
  let release = DispatchSemaphore(value: 0)
  let disconnected = DispatchSemaphore(value: 0)
  let started = DispatchSemaphore(value: 0)
  delivery.connect { frame in
    precondition(frame == 1)
    entered.signal()
    precondition(release.wait(timeout: .now() + 5) == .success)
  }
  let publishing = Task.detached { delivery.submit(1) }
  precondition(entered.wait(timeout: .now() + 5) == .success)
  let disconnecting = Task.detached {
    started.signal()
    delivery.disconnect()
    disconnected.signal()
  }
  precondition(started.wait(timeout: .now() + 5) == .success)
  precondition(
    disconnected.wait(timeout: .now()) == .timedOut, "Disconnect waits for an in-flight publication"
  )
  release.signal()
  await publishing.value
  await disconnecting.value
  delivery.submit(2)
  let next = ConversionFrameDelivery<Int>()
  var received = 0
  next.connect { received = $0 }
  delivery.submit(3)
  precondition(received == 0, "Old session cannot deliver to a new renderer")
  next.submit(4)
  precondition(received == 4, "New session publishes immediately without a main-actor queue")
  next.disconnect()
  print("PASS direct frame delivery: teardown drains publication and isolates later sessions")
}
