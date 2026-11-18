// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PagewormActivity",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PagewormActivity", targets: ["PagewormActivity"])
    ],
    targets: [
        .target(name: "PagewormActivity")
    ]
)
