// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "macos-gui",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "ClocGUI", targets: ["macos-gui"]),
    ],
    targets: [
        .executableTarget(
            name: "macos-gui"
        ),
    ]
)
