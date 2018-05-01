// swift-tools-version:4.0

import PackageDescription

let pkg = Package(name: "CancellablePromiseKit")
pkg.products = [
    .library(name: "CancellablePromiseKit", targets: ["CancellablePromiseKit"]),
]

let pmk: Target = .target(name: "CancellablePromiseKit")
pmk.path = "Sources"
pmk.exclude = [
    "after.m"
]
pkg.swiftLanguageVersions = [3, 4]
pkg.targets = [
    pmk,
    .testTarget(name: "A+", dependencies: ["CancellablePromiseKit"]),
]
