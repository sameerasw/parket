// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Workspacer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "WorkspacerCore",
            path: "Workspacer/Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "workspacer",
            dependencies: ["WorkspacerCore"],
            path: "Workspacer/Entry"
        ),
        .executableTarget(
            name: "workspacer-tests",
            dependencies: ["WorkspacerCore"],
            path: "Tests"
        ),
    ]
)
