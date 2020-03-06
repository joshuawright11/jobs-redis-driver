// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "jobs-redis-driver",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "JobsRedisDriver",
            targets: ["JobsRedisDriver"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/joshuawright11/jobs.git", .branch("master")),
        .package(url: "https://github.com/vapor/redis-kit.git", from: "1.0.0-beta"),
    ],
    targets: [
        .target(
            name: "JobsRedisDriver",
            dependencies: ["Jobs", "RedisKit"]
        ),
        .testTarget(
            name: "JobsRedisDriverTests",
            dependencies: ["JobsRedisDriver", "XCTVapor"]
        ),
    ]
)
