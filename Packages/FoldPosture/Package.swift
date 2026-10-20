// swift-tools-version: 6.2
import PackageDescription

// Shared across Carriage, Grid Fleet and Dawnfold. Keep it free of app-specific code.
let package = Package(
    name: "FoldPosture",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "FoldPosture", targets: ["FoldPosture"]),
    ],
    targets: [
        .target(name: "FoldPosture"),
        .testTarget(name: "FoldPostureTests", dependencies: ["FoldPosture"]),
    ]
)
