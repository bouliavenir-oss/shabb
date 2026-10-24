// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ShabbatCore", platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "ShabbatCore", targets: ["ShabbatCore"])],
    targets: [.target(name: "ShabbatCore", path: "ios/Scheduler"),
              .testTarget(name: "ShabbatCoreTests", dependencies: ["ShabbatCore"], path: "tests/Core")])
