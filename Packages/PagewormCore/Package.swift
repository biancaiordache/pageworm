// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PagewormCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PagewormCore", targets: ["PagewormCore"])
    ],
    targets: [
        .target(name: "PagewormCore"),
        .testTarget(name: "PagewormCoreTests", dependencies: ["PagewormCore"])
    ]
)
