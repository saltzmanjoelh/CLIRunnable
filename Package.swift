// swift-tools-version:4.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CliRunnable",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CliRunnable",
            type: .static,
            targets: ["CliRunnable"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/saltzmanjoelh/Yaml.git", from: "3.0.0"),
        .package(url: "https://github.com/saltzmanjoelh/ProcessRunner.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CliRunnable",
            dependencies: ["Yaml"]),
        .testTarget(
            name: "CliRunnableTests",
            dependencies: ["CliRunnable", "Yaml"]),
    ]
)
