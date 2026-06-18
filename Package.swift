// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LightsOutSafetyCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LightsOutSafetyCore",
            targets: ["LightsOutSafetyCore"]
        )
    ],
    targets: [
        .target(
            name: "LightsOutSafetyCore",
            path: "LightsOut/Services"
        ),
        .executableTarget(
            name: "LightsOutSafetyCoreChecks",
            dependencies: ["LightsOutSafetyCore"],
            path: "Checks/LightsOutSafetyCoreChecks"
        )
    ]
)
