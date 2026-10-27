// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PicRopeForMac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PicRopeForMac",
            path: "Sources/PicRopeForMac"
        )
    ]
)
