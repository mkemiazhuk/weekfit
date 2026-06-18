// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekFitHealthKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WeekFitHealthKit", targets: ["WeekFitHealthKit"]),
    ],
    dependencies: [
        .package(path: "../WeekFitPlanner"),
    ],
    targets: [
        .target(
            name: "WeekFitHealthKit",
            dependencies: [
                .product(name: "WeekFitPlanner", package: "WeekFitPlanner"),
            ]
        ),
        .testTarget(
            name: "WeekFitHealthKitTests",
            dependencies: ["WeekFitHealthKit"]
        ),
    ]
)
