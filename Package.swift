// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiftLogCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LiftLogCore", targets: ["LiftLogCore"])],
    targets: [
        .target(name: "LiftLogCore", path: "LiftLog/Core"),
        .testTarget(name: "LiftLogCoreTests", dependencies: ["LiftLogCore"], path: "Tests/LiftLogCoreTests")
    ]
)
