// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProspectorMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ProspectorMac", targets: ["ProspectorMac"])
    ],
    targets: [
        .executableTarget(
            name: "ProspectorMac",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)