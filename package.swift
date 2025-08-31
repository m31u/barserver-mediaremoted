// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "barserver-mediaremoted",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "barserver-mediaremoted",
            targets: ["barserver-mediaremoted"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PrivateFrameworks/MediaRemote",
            .upToNextMinor(from: "0.1.0")
        )
    ],
    targets: [
        .executableTarget(
            name: "barserver-mediaremoted",
            dependencies: [
                .product(name: "PrivateMediaRemote", package: "MediaRemote"),
                .product(name: "MediaRemote", package: "MediaRemote"),
            ]
        )
    ]
)
