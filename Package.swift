// swift-tools-version: 5.9

import Foundation
import PackageDescription

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let vision = root + "/.tools/opencv43-install"
let inference = root + "/.tools/litert-native"
let faceInference = root + "/.tools/onnx-native"

let package = Package(
  name: "Macdissey3D",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "OdysseyMenu", targets: ["OdysseyMenu"])],
  targets: [
    .target(
      name: "OdysseyVision",
      cxxSettings: [
        .unsafeFlags(["-I" + vision + "/include/opencv4", "-ffp-contract=off"])
      ],
      linkerSettings: [
        .unsafeFlags(["-L" + vision + "/lib", "-L" + vision + "/lib/opencv4/3rdparty"]),
        .linkedLibrary("opencv_calib3d"), .linkedLibrary("opencv_features2d"),
        .linkedLibrary("opencv_flann"), .linkedLibrary("opencv_imgproc"),
        .linkedLibrary("opencv_core"), .linkedLibrary("z"),
      ]),
    .target(
      name: "OdysseyInference",
      cxxSettings: [
        .unsafeFlags([
          "-I" + inference + "/include", "-I" + faceInference + "/include", "-ffp-contract=off",
        ])
      ],
      linkerSettings: [
        .unsafeFlags([
          "-L" + inference + "/lib", "-Xlinker", "-rpath", "-Xlinker",
          "@executable_path/../Frameworks", "-Xlinker", "-rpath", "-Xlinker", inference + "/lib",
        ]),
        .unsafeFlags([
          "-L" + faceInference + "/lib", "-Xlinker", "-rpath", "-Xlinker", faceInference + "/lib",
        ]),
        .linkedLibrary("LiteRt"), .linkedLibrary("onnxruntime"),
      ]),
    .target(name: "OdysseyCore", dependencies: ["OdysseyVision", "OdysseyInference"]),
    .target(name: "OdysseyCamera", dependencies: ["OdysseyCore"]),
    .target(name: "OdysseyGL", linkerSettings: [.linkedFramework("OpenGL")]),
    .target(name: "OdysseyRendering", dependencies: ["OdysseyCore"]),
    .target(name: "OdysseyMonitor"),
    .executableTarget(
      name: "OdysseyMenu",
      dependencies: [
        "OdysseyCore", "OdysseyCamera", "OdysseyGL", "OdysseyRendering", "OdysseyMonitor",
      ]),
    .executableTarget(
      name: "DisplayColorChecks", dependencies: ["OdysseyRendering"],
      path: "Tests/DisplayColorChecks"),
    // Command Line Tools installations do not ship XCTest. These checks
    // run on the same minimal toolchain used to build the application.
    .executableTarget(name: "CoreChecks", dependencies: ["OdysseyCore"], path: "Tests/CoreChecks"),
    .executableTarget(
      name: "FactoryCalibrationChecks", dependencies: ["OdysseyCore"],
      path: "Tests/FactoryCalibrationChecks"),
  ],
  cxxLanguageStandard: .cxx17
)
