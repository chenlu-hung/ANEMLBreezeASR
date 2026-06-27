// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ANEMLBreezeASR",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMinor(from: "1.1.2")),
        .package(url: "https://github.com/dagronf/SwiftSubtitles", from: "2.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ANEMLBreezeASR",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "SwiftSubtitles", package: "SwiftSubtitles")
            ],
            path: "Sources/ANEMLBreezeASR"
        ),
        .testTarget(
            name: "ANEMLBreezeASRTests",
            dependencies: ["ANEMLBreezeASR"],
            path: "Tests/ANEMLBreezeASRTests"
        )
    ]
)
