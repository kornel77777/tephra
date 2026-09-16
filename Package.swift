// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LectureRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "lecture-recorder-cli", targets: ["lecture-recorder-cli"]),
        .executable(name: "LectureRecorderApp", targets: ["LectureRecorderApp"]),
        .library(name: "LectureRecorderCore", targets: ["LectureRecorderCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "LectureRecorderCore",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ]
        ),
        .executableTarget(
            name: "lecture-recorder-cli",
            dependencies: ["LectureRecorderCore"]
        ),
        .executableTarget(
            name: "LectureRecorderApp",
            dependencies: ["LectureRecorderCore"]
        )
    ]
)
