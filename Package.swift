// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PromptPalette",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "PromptPalette", targets: ["PromptPalette"]),
    ],
    targets: [
        .executableTarget(
            name: "PromptPalette",
            path: "Sources"
        ),
        .testTarget(
            name: "PromptPaletteTests",
            dependencies: ["PromptPalette"],
            path: "Tests/PromptPaletteTests"
        ),
    ]
)
