import Foundation

/// Recovered SREyeTracker camera-to-display transform (RVA 0x181ce0).
/// This is the factory Transform path with identity upstream camera extrinsics.
public struct DisplayTransform {
  public let rotationDegrees: SIMD3<Double>
  public let translationCentimetres: SIMD3<Double>
  public let crossVerticalPosition: Double
  public init(factory: FactoryTrackerCalibration) throws {
    // SRService writes the six CALET values to an INI with %.6f before
    // SREyeTracker reads them. Its constructor initializes cross to zero;
    // the RealSense-only value of eight does not apply to ET's camera.
    func rounded(_ values: [Double]) -> SIMD3<Double> {
      let v = values.map {
        Double(String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), $0))!
      }
      return SIMD3(v[0], v[1], v[2])
    }
    try self.init(
      rotationDegrees: rounded(factory.rotationDegrees),
      translationCentimetres: rounded(factory.translationCentimetres))
  }
  public init(
    rotationDegrees: SIMD3<Double>, translationCentimetres: SIMD3<Double>,
    crossVerticalPosition: Double = 0
  ) throws {
    guard
      (0..<3).allSatisfy({ rotationDegrees[$0].isFinite && translationCentimetres[$0].isFinite }),
      crossVerticalPosition.isFinite
    else { throw TrackingMathError.invalidInput }
    self.rotationDegrees = rotationDegrees
    self.translationCentimetres = translationCentimetres
    self.crossVerticalPosition = crossVerticalPosition
  }
  public func apply(centimetres point: SIMD3<Float>) throws -> SIMD3<Float> {
    guard (0..<3).allSatisfy({ point[$0].isFinite }) else { throw TrackingMathError.invalidInput }
    let radians = 0.017453292519943295
    let yAngle = rotationDegrees.y * radians
    let xAngle = rotationDegrees.x * radians
    let zAngle = Double.pi.addingProduct(radians, rotationDegrees.z)
    let sy = sin(yAngle)
    let cy = cos(yAngle)
    let sx = sin(xAngle)
    let cx = cos(xAngle)
    let sz = sin(zAngle)
    let cz = cos(zAngle)
    guard abs(cy) > 1e-12, abs(cx) > 1e-12 else { throw TrackingMathError.invalidInput }
    let y = translationCentimetres.y / cy + Double(point.y)
    let z = Double(point.z)
    let z1 = (z * cy).addingProduct(sy, y)
    let inverseX = 1 / cx
    let tilt = atan(sx * inverseX * cy)
    let st = sin(tilt)
    let ct = cos(tilt)
    let x1 = Double(point.x).addingProduct(inverseX, translationCentimetres.x)
    let x2 = (-st * z1).addingProduct(ct, x1)
    let y1 = (-z * sy).addingProduct(cy, y)
    let shifted = y1 + crossVerticalPosition
    let output = SIMD3(
      Float((x2 * cz).addingProduct(sz, shifted)),
      Float(crossVerticalPosition.addingProduct(cz, shifted) - x2 * sz),
      Float(ct * z1 + translationCentimetres.z.addingProduct(st, x1)))
    guard (0..<3).allSatisfy({ output[$0].isFinite }) else { throw TrackingMathError.invalidInput }
    return output
  }
  public func apply(millimetres point: SIMD3<Float>) throws -> SIMD3<Float> {
    try apply(centimetres: point * Float(0.1))
  }
}
