// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PagewormDesign",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PagewormDesign", targets: ["PagewormDesign"])
    ],
    dependencies: [
        .package(path: "../PagewormCore")
    ],
    targets: [
        .target(
            name: "PagewormDesign",
            dependencies: ["PagewormCore"]
        )
    ]
)
