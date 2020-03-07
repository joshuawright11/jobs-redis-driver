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
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0-rc"),
        .package(url: "https://github.com/joshuawright11/redis-kit.git", .branch("reset")),
    ],
    targets: [
        .target(
            name: "JobsRedisDriver",
            dependencies: ["Queues", "RedisKit"]
        ),
        .testTarget(
            name: "JobsRedisDriverTests",
            dependencies: ["JobsRedisDriver", "XCTVapor"]
        ),
    ]
)
