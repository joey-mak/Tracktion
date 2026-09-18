// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "RaceWeekCore", platforms: [.macOS(.v13)], products: [.library(name: "RaceWeekCore", targets: ["RaceWeekCore"])], targets: [.target(name: "RaceWeekCore", path: "Sources/Core"), .testTarget(name: "RaceWeekCoreTests", dependencies: ["RaceWeekCore"], path: "Tests/Core")], swiftLanguageModes: [.v5])
