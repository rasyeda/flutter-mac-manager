// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlutterMacManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FlutterMacManagerCore",
            targets: ["FlutterMacManagerCore"]
        ),
        .executable(
            name: "FlutterMacManager",
            targets: ["FlutterMacManager"]
        )
    ],
    targets: [
        .target(
            name: "FlutterMacManagerCore",
            path: "Sources/FlutterMacManagerCore"
        ),
        .executableTarget(
            name: "FlutterMacManager",
            dependencies: ["FlutterMacManagerCore"],
            path: "Sources/FlutterMacManager"
        ),
        .testTarget(
            name: "FlutterMacManagerTests",
            dependencies: ["FlutterMacManagerCore"],
            path: "Tests/FlutterMacManagerTests"
        )
    ]
)
