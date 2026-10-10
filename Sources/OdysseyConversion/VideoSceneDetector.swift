import Foundation

/// Detect abrupt shot changes before recurrent inference. Gradual motion with a
/// similar colour distribution keeps its context; cuts discard unrelated history.
struct VideoSceneDetector {
  private var previous: [Float]?
  private var histogram: [Float]?

  mutating func reset() {
    previous = nil
    histogram = nil
  }

  mutating func changed(_ image: [Float], width: Int, height: Int) -> Bool {
    let pixels = width * height
    precondition(image.count == pixels * 3)
    let mean: [Float] = [0.485, 0.456, 0.406]
    let std: [Float] = [0.229, 0.224, 0.225]
    var sample: [Float] = []
    var bins = [Float](repeating: 0, count: 48)
    let columns = min(32, width)
    let rows = min(18, height)
    sample.reserveCapacity(columns * rows * 3)
    for y in 0..<rows {
      for x in 0..<columns {
        let offset =
          ((2 * y + 1) * height / (2 * rows)) * width + (2 * x + 1) * width / (2 * columns)
        for channel in 0..<3 {
          let value = max(
            0, min(1, image[channel * pixels + offset] * std[channel] + mean[channel]))
          sample.append(value)
          bins[channel * 16 + min(15, Int(value * 16))] += 1 / Float(columns * rows)
        }
      }
    }
    defer {
      previous = sample
      histogram = bins
    }
    guard let previous, let histogram else { return true }
    var difference: Float = 0
    var changedPixels = 0
    for pixel in 0..<(columns * rows) {
      var error: Float = 0
      for channel in 0..<3 {
        error += abs(sample[pixel * 3 + channel] - previous[pixel * 3 + channel]) / 3
      }
      difference += error / Float(columns * rows)
      if error > 0.2 { changedPixels += 1 }
    }
    let distribution = zip(bins, histogram).reduce(Float(0)) { $0 + abs($1.0 - $1.1) } / 6
    let widespread = Float(changedPixels) / Float(columns * rows)
    return difference > 0.25 && widespread > 0.7 && (distribution > 0.3 || difference > 0.45)
  }
}
