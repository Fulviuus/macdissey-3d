import Foundation
import Metal

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else { fatalError(message) }
}

@main enum DepthMapResamplingChecks {
  static func main() throws {
    let gpu = try ConversionGPU(root: FileManager.default.temporaryDirectory)
    let resampler = try DepthMapResampler(gpu: gpu)
    let width = 518
    let height = 294
    let side = 512
    let source = try gpu.texture(width, height, format: .r32Float)
    let destination = try gpu.texture(side, side, format: .r32Float)
    // A positive, asymmetric ramp exposes missing rows, cropped columns,
    // aspect-ratio mistakes, and an incorrect vertical orientation.
    let values = (0..<(width * height)).map { i in
      Float(1) + Float(i % width) / Float(width) + 2 * Float(i / width) / Float(height)
    }
    values.withUnsafeBytes {
      source.replace(
        region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
        withBytes: $0.baseAddress!, bytesPerRow: width * 4)
    }
    try resampler.run(gpu: gpu, source: source, output: destination)
    var result = [Float](repeating: .nan, count: side * side)
    result.withUnsafeMutableBytes {
      destination.getBytes(
        $0.baseAddress!, bytesPerRow: side * 4,
        from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
    }
    for y in 0..<side {
      for x in 0..<side {
        let sx = min(Float(width - 1), max(0, (Float(x) + 0.5) * Float(width) / Float(side) - 0.5))
        let sy = min(
          Float(height - 1), max(0, (1 - (Float(y) + 0.5) / Float(side)) * Float(height) - 0.5))
        let expected = 1 + sx / Float(width) + 2 * sy / Float(height)
        require(
          abs(result[y * side + x] - expected) < 0.002, "Depth coverage/orientation at \(x),\(y)")
      }
    }
    print("PASS rectangular depth map: every pixel, full extent, vertical flip and interpolation")
  }
}
