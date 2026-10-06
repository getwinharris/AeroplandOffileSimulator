// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AeroplaneSimulatorOffline",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AeroplaneSimulatorOffline", targets: ["AeroplaneSimulatorOffline"])
    ],
    targets: [
        .executableTarget(
            name: "AeroplaneSimulatorOffline",
            path: "Sources/AeroplaneSimulatorOffline"
        )
    ]
)
