// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WearwiseCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "WearwiseCore", targets: ["WearwiseCore"])],
    targets: [
        .target(name: "WearwiseCore"),
        .testTarget(name: "WearwiseCoreTests", dependencies: ["WearwiseCore"])
    ],
    swiftLanguageModes: [.v6]
)
