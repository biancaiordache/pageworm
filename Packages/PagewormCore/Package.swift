// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PagewormCore",
    products: [
        .library(name: "PagewormCore", targets: ["PagewormCore"])
    ],
    targets: [
        .target(name: "PagewormCore"),
        .testTarget(name: "PagewormCoreTests", dependencies: ["PagewormCore"])
    ]
)
