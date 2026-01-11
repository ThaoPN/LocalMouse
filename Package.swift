// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalMouse",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LocalMouseHelper", targets: ["LocalMouseHelper"]),
    ],
    targets: [
        // Shared library
        .target(
            name: "Shared",
            path: "Shared"
        ),

        // Helper executable (background daemon)
        .executableTarget(
            name: "LocalMouseHelper",
            dependencies: ["Shared"],
            path: "Helper"
        ),
    ]
)
