// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekFitWorkoutMetrics",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WeekFitWorkoutMetrics", targets: ["WeekFitWorkoutMetrics"]),
    ],
    targets: [
        .target(name: "WeekFitWorkoutMetrics"),
        .testTarget(
            name: "WeekFitWorkoutMetricsTests",
            dependencies: ["WeekFitWorkoutMetrics"]
        ),
    ]
)
