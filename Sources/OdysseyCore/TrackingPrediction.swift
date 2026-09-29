import Foundation

// Reconstructed from SREyeTracker 1.11.0.
// Keep scalar operation order: automatic vector reductions change rounding.
public enum TrackingMathError: Error {
  case invalidInput, singularRegression, insufficientHistory
}

public struct TrackingSample {
  public let position: SIMD3<Double>
  public let timestamp: Double
  public init(position: SIMD3<Double>, timestamp: Double) {
    self.position = position
    self.timestamp = timestamp
  }
}

public struct HistoryPredictionConfiguration {
  public var counts: SIMD3<Int32>
  public var velocityScales: SIMD3<Double>
  public var outliers: SIMD3<Int32>
  public var projectToFixedDepth: Bool
  public var fixedDepth: Double
  public var horizon: Double
  public init(
    counts: SIMD3<Int32>, velocityScales: SIMD3<Double>, outliers: SIMD3<Int32>,
    projectToFixedDepth: Bool, fixedDepth: Double, horizon: Double
  ) {
    self.counts = counts
    self.velocityScales = velocityScales
    self.outliers = outliers
    self.projectToFixedDepth = projectToFixedDepth
    self.fixedDepth = fixedDepth
    self.horizon = horizon
  }
}

public enum TrackingPrediction {
  private static func coefficients(_ x: [Double], _ y: [Double]) throws -> (Double, Double, Double)
  {
    guard x.count == y.count, x.count >= 3,
      x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite)
    else { throw TrackingMathError.invalidInput }
    var lanes = Array(repeating: Array(repeating: 0.0, count: 4), count: 7)
    let vectorEnd = x.count & ~3
    for i in 0..<vectorEnd {
      let xx = x[i] * x[i]
      let xxx = (x[i] * x[i]) * x[i]
      let lane = i & 3
      let terms = [x[i], y[i], 0, xx, xxx, xx * y[i], xxx * x[i]]
      for j in 0..<7 {
        lanes[j][lane] = j == 2 ? fma(x[i], y[i], lanes[j][lane]) : lanes[j][lane] + terms[j]
      }
    }
    var sums = lanes.map { ($0[2] + $0[3]) + ($0[0] + $0[1]) }
    for i in vectorEnd..<x.count {
      let xx = x[i] * x[i]
      let xxx = (x[i] * x[i]) * x[i]
      sums[0] += x[i]
      sums[1] += y[i]
      sums[2] = fma(x[i], y[i], sums[2])
      sums[3] += xx
      sums[4] += xxx
      sums[5] = fma(y[i], xx, sums[5])
      sums[6] = fma(x[i], xxx, sums[6])
    }
    let sx = sums[0]
    let sy = sums[1]
    let sxx = sums[3]
    let inverseN = 1.0 / Double(x.count)
    let a = fma(-inverseN, sx * sx, sxx)
    let b = fma(-inverseN, sy * sx, sums[2])
    let c = fma(-inverseN, sxx * sx, sums[4])
    let d = fma(-inverseN, sxx * sy, sums[5])
    let e = fma(-inverseN, sxx * sxx, sums[6])
    let denominator = fma(a, e, -(c * c))
    guard denominator.isFinite, denominator != 0 else { throw TrackingMathError.singularRegression }
    let inverse = 1.0 / denominator
    let quadratic = fma(a, d, -(c * b)) * inverse
    let linear = (e * b - d * c) * inverse
    let constant = (fma(-sx, linear, sy) - quadratic * sxx) * inverseN
    guard quadratic.isFinite, linear.isFinite, constant.isFinite else {
      throw TrackingMathError.singularRegression
    }
    return (quadratic, linear, constant)
  }

  public static func trim(_ x: [Double], _ y: [Double], iterations: Int) throws -> (
    [Double], [Double]
  ) {
    guard x.count == y.count else { throw TrackingMathError.invalidInput }
    var x = x
    var y = y
    for _ in 0..<max(0, min(iterations, x.count)) {
      if x.count < 11 { break }
      let (a, b, c) = try coefficients(x, y)
      var worst = 0.0
      var index = 0
      for i in x.indices {
        let residual = abs(fma(x[i], fma(a, x[i], b), c) - y[i])
        if residual > worst {
          worst = residual
          index = i
        }
      }
      x.remove(at: index)
      y.remove(at: index)
    }
    return (x, y)
  }

  public static func fit(_ x: [Double], _ y: [Double], time: Double, outliers: Int = 0)
    throws -> (value: Double, slope: Double)
  {
    guard time.isFinite else { throw TrackingMathError.invalidInput }
    let (tx, ty) = try trim(x, y, iterations: outliers)
    let (a, b, c) = try coefficients(tx, ty)
    return ((a * time + b) * time + c, (a + a) * time + b)
  }

  public static func predict(
    _ history: [TrackingSample], now: Double,
    configuration c: HistoryPredictionConfiguration
  ) throws -> SIMD3<Double> {
    guard now.isFinite, c.fixedDepth.isFinite, c.horizon.isFinite,
      !c.projectToFixedDepth || c.fixedDepth != 0
    else { throw TrackingMathError.invalidInput }
    for h in history {
      guard h.timestamp.isFinite, (0..<3).allSatisfy({ h.position[$0].isFinite }),
        !c.projectToFixedDepth || h.position.z != 0
      else { throw TrackingMathError.invalidInput }
    }
    guard let last = history.last else { return SIMD3(0, 0, 60) }
    if history.count < 3 { return last.position }
    let n = history.count
    let starts = (0..<3).map { max(0, min(n - 1, n - Int(c.counts[$0]))) }
    let origin = history[starts[0] + ((n - starts[0]) >> 1)].timestamp
    var xs = [[Double]]()
    var ys = [[Double]]()
    for axis in 0..<3 {
      guard c.velocityScales[axis].isFinite else { throw TrackingMathError.invalidInput }
      xs.append(history[starts[axis]...].map { $0.timestamp - origin })
      ys.append(
        history[starts[axis]...].map {
          c.projectToFixedDepth && axis < 2
            ? ($0.position[axis] / $0.position.z) * c.fixedDepth : $0.position[axis]
        })
    }
    var derivatives = [SIMD3<Double>]()
    for endpoint in [history[0].timestamp, last.timestamp] {
      let time = (endpoint - origin) * 0.5
      var derivative = SIMD3<Double>(repeating: 0)
      for i in 0..<3 {
        derivative[i] = try fit(xs[i], ys[i], time: time, outliers: Int(c.outliers[i])).slope
      }
      if c.projectToFixedDepth {
        for i in 0..<2 { derivative[i] = (derivative.z * derivative[i]) * (1.0 / c.fixedDepth) }
      }
      derivatives.append(derivative)
    }
    let cap = (last.timestamp + 0.2) - now
    let relative = origin - now
    let delta = c.horizon - relative
    var output = SIMD3<Double>(repeating: 0)
    for i in 0..<3 {
      let weight =
        c.velocityScales[i] == 0
        ? 1.0
        : max(
          0,
          min(
            1,
            sqrt(max(abs(derivatives[0][i]), abs(derivatives[1][i]))) * (1.0 / c.velocityScales[i]))
        )
      let time = (min(fma(delta, weight, relative), cap) + now) - origin
      output[i] = try fit(xs[i], ys[i], time: time, outliers: Int(c.outliers[i])).value
    }
    if c.projectToFixedDepth {
      for i in 0..<2 { output[i] = (output[i] * (1.0 / c.fixedDepth)) * output.z }
    }
    return output
  }
}

public struct PoseSpeedLimiter {
  public private(set) var state: [Double]
  public init(state: [Double]) throws {
    guard state.count == 7, state.allSatisfy(\.isFinite) else {
      throw TrackingMathError.invalidInput
    }
    self.state = state
  }
  public mutating func initialize(_ position: SIMD3<Double>, time: Double) {
    for i in 0..<3 { state[i] = position[i] }
    state[3] = time
  }
  public mutating func apply(_ position: SIMD3<Double>, time: Double) -> SIMD3<Double> {
    let dt = time - state[3]
    var output = position
    if dt > 0.0001 {
      let inverse = 1.0 / dt
      for i in 0..<3 {
        var velocity = inverse * (position[i] - state[i])
        if state[4 + i] < abs(velocity) { velocity = (velocity >= 0 ? 1 : -1) * state[4 + i] }
        output[i] = state[i] + velocity * dt
      }
      if (0..<3).contains(where: { output[$0].isNaN }) { output = position }
    }
    initialize(output, time: time)
    return output
  }
}

public struct PoseNoiseRejection {
  public private(set) var state: [Double]
  public init(state: [Double]) throws {
    guard state.count == 18, state.allSatisfy(\.isFinite) else {
      throw TrackingMathError.invalidInput
    }
    self.state = state
  }
  public mutating func apply(_ position: SIMD3<Double>, velocity: SIMD3<Double>) -> SIMD3<Double> {
    var output = SIMD3<Double>(repeating: 0)
    for i in 0..<3 {
      let delta = position[i] - state[3 + i]
      let smoothed = delta * state[6 + i] + state[3 + i]
      state[i] = (state[9 + i] - state[i]) * state[15 + i] + state[i]
      if state[12 + i] < abs(velocity[i]) { state[i] = 0 }
      output[i] = state[3 + i]
      if state[i] < abs(delta) {
        output[i] = fma(abs(delta) - state[i], copysign(1.0, delta), output[i])
      }
      if abs(delta) <= state[i] { output[i] = smoothed }
    }
    if (0..<3).contains(where: { output[$0].isNaN }) { output = position }
    for i in 0..<3 { state[3 + i] = output[i] }
    return output
  }
}

public struct PoseOutputConfiguration {
  public var history: HistoryPredictionConfiguration
  public var ipd: SIMD3<Double>
  public var ipdThreshold: Double, ipdTarget: Double, maxPredictionDistance: Double
  public var prediction: Bool, depthPrediction: Bool, exponentialSmoothing: Bool,
    noiseRejection: Bool, rawMode: Bool
  public init(
    history: HistoryPredictionConfiguration, ipd: SIMD3<Double>, ipdThreshold: Double,
    ipdTarget: Double, maxPredictionDistance: Double, prediction: Bool, depthPrediction: Bool,
    exponentialSmoothing: Bool, noiseRejection: Bool, rawMode: Bool
  ) {
    self.history = history
    self.ipd = ipd
    self.ipdThreshold = ipdThreshold
    self.ipdTarget = ipdTarget
    self.maxPredictionDistance = maxPredictionDistance
    self.prediction = prediction
    self.depthPrediction = depthPrediction
    self.exponentialSmoothing = exponentialSmoothing
    self.noiseRejection = noiseRejection
    self.rawMode = rawMode
  }
}

public struct PoseOutputFilter {
  public var configuration: PoseOutputConfiguration
  public private(set) var speed: PoseSpeedLimiter, noise: PoseNoiseRejection
  public private(set) var smoothing: [Double]
  public init(
    configuration: PoseOutputConfiguration, speed: [Double], smoothing: [Double], noise: [Double]
  ) throws {
    guard smoothing.count == 6, smoothing.allSatisfy(\.isFinite) else {
      throw TrackingMathError.invalidInput
    }
    self.configuration = configuration
    self.speed = try PoseSpeedLimiter(state: speed)
    self.noise = try PoseNoiseRejection(state: noise)
    self.smoothing = smoothing
  }
  public mutating func apply(_ history: [TrackingSample], now: Double)
    throws -> (left: SIMD3<Double>, right: SIMD3<Double>)
  {
    let c = configuration
    guard now.isFinite, c.ipdThreshold.isFinite, c.ipdTarget.isFinite,
      c.maxPredictionDistance.isFinite, (0..<3).allSatisfy({ c.ipd[$0].isFinite })
    else { throw TrackingMathError.invalidInput }
    guard
      history.allSatisfy({ sample in
        sample.timestamp.isFinite && (0..<3).allSatisfy { sample.position[$0].isFinite }
      })
    else { throw TrackingMathError.invalidInput }
    var center: SIMD3<Double>
    if c.rawMode {
      center = history.last?.position ?? SIMD3(0, 0, 60)
    } else {
      guard history.count >= 6 else { throw TrackingMathError.insufficientHistory }
      center = try TrackingPrediction.predict(history, now: now, configuration: c.history)
      let last = history[history.count - 1].position
      var delta = center - last
      let length = sqrt((delta.x * delta.x + delta.y * delta.y) + delta.z * delta.z)
      if c.maxPredictionDistance < length {
        for i in 0..<3 { delta[i] = ((1.0 / length) * c.maxPredictionDistance) * delta[i] }
      }
      center = last + delta
      if !c.prediction {
        center = last
      } else if !c.depthPrediction {
        if c.history.projectToFixedDepth {
          let inverse = 1.0 / center.z
          for i in 0..<3 { center[i] = (inverse * center[i]) * last.z }
        } else {
          center.z = last.z
        }
      }
      if speed.state[3] <= 0 {
        speed.initialize(center, time: now)
      } else {
        center = speed.apply(center, time: now)
      }
      if c.exponentialSmoothing {
        var filtered = SIMD3<Double>(repeating: 0)
        for i in 0..<3 {
          filtered[i] = smoothing[i] + (center[i] - smoothing[i]) * smoothing[3 + i]
        }
        if !(0..<3).contains(where: { filtered[$0].isNaN }) { center = filtered }
        for i in 0..<3 { smoothing[i] = center[i] }
      }
      if c.noiseRejection {
        let previous = history[history.count - 2]
        let inverse = 1.0 / (history[history.count - 1].timestamp - previous.timestamp)
        var velocity = SIMD3<Double>(repeating: 0)
        for i in 0..<3 { velocity[i] = inverse * (last[i] - previous.position[i]) }
        center = noise.apply(center, velocity: velocity)
      }
    }
    var ipd = c.ipd
    let length = hypot(hypot(ipd.x, ipd.y), ipd.z)
    if c.ipdThreshold < length {
      for i in 0..<3 {
        ipd[i] =
          c.rawMode
          ? ((1.0 / length) * c.ipdTarget) * ipd[i] : ((1.0 / length) * ipd[i]) * c.ipdTarget
      }
    }
    let half = ipd * 0.5
    return (center - half, center + half)
  }
}

/// The vendor's bounded midpoint history and per-axis rolling IPD mean.
/// Counts are explicit product configuration; no camera calibration is inferred.
public struct PoseHistory {
  public private(set) var samples: [TrackingSample] = []
  public private(set) var ipd = SIMD3<Double>(repeating: 0)
  private let historyLimit: Int
  private let ipdLimits: SIMD3<Int32>
  private var ipdSamples = [[Double](), [Double](), [Double]()]

  public init(counts: SIMD3<Int32>, ipdCounts: SIMD3<Int32>) throws {
    guard (0..<3).allSatisfy({ counts[$0] > 0 && ipdCounts[$0] > 0 }) else {
      throw TrackingMathError.invalidInput
    }
    self.historyLimit = Int(max(counts.x, max(counts.y, counts.z)))
    self.ipdLimits = ipdCounts
  }

  public mutating func add(left: SIMD3<Double>, right: SIMD3<Double>, time: Double) throws {
    guard time.isFinite, (0..<3).allSatisfy({ left[$0].isFinite && right[$0].isFinite }) else {
      throw TrackingMathError.invalidInput
    }
    var center = SIMD3<Double>(repeating: 0)
    for i in 0..<3 { center[i] = (left[i] + right[i]) * 0.5 }
    samples.append(TrackingSample(position: center, timestamp: time))
    if samples.count > historyLimit { samples.removeFirst() }
    for i in 0..<3 {
      // Do not recompute the sum: the original updates from its rounded mean.
      var total = Double(ipdSamples[i].count) * ipd[i]
      let separation = right[i] - left[i]
      ipdSamples[i].append(separation)
      total += separation
      if ipdSamples[i].count > Int(ipdLimits[i]) { total -= ipdSamples[i].removeFirst() }
      ipd[i] = total / Double(ipdSamples[i].count)
    }
  }
}
