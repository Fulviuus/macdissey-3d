import Foundation
import OdysseyVision

public struct WeaverAttributes {
  public let phase, ray: SIMD4<Float>
  public let screen, weave: SIMD2<Float>
  public var values: [Float] {
    [
      phase.x, phase.y, phase.z, phase.w, ray.x, ray.y, ray.z, ray.w, screen.x, screen.y, weave.x,
      weave.y,
    ]
  }
  public init(
    profile: FactoryOpticalProfile, eyeCentimetres: SIMD3<Float>,
    vertex: SIMD2<Float>, resolution: SIMD2<Float> = SIMD2(3840, 2160),
    offset: SIMD2<Float> = .zero
  ) throws {
    guard (0..<3).allSatisfy({ eyeCentimetres[$0].isFinite }), eyeCentimetres.z > 0,
      vertex.x.isFinite, vertex.y.isFinite,
      resolution.x.isFinite, resolution.y.isFinite, resolution.x > 0, resolution.y > 0,
      offset.x.isFinite, offset.y.isFinite, profile.pixelLayout == "LRGB"
    else {
      throw TrackingMathError.invalidInput
    }
    let p: [Float] = [
      profile.slant, profile.pitch, profile.spacingCentimetres,
      profile.spacingCentimetres / profile.pixelSizeCentimetres, profile.refractiveIndex,
      profile.phase * 28, 0, profile.pixelSizeCentimetres,
    ]
    var out = [Float](repeating: 0, count: 12)
    odyssey_weave_attributes(
      p, [eyeCentimetres.x, eyeCentimetres.y, eyeCentimetres.z],
      [resolution.x, resolution.y], [offset.x, offset.y], [vertex.x, vertex.y], &out)
    guard out.allSatisfy(\.isFinite) else { throw TrackingMathError.invalidInput }
    phase = SIMD4(out[0], out[1], out[2], out[3])
    ray = SIMD4(out[4], out[5], out[6], out[7])
    screen = SIMD2(out[8], out[9])
    weave = SIMD2(out[10], out[11])
  }
}
