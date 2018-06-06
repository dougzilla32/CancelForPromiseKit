// swift-tools-version:4.0

import PackageDescription

let pkg = Package(name: "CancelForPromiseKit")
pkg.products = [
    .library(name: "CancelForPromiseKit", targets: ["CancelForPromiseKit"]),
]

let cpk: Target = .target(name: "CancelForPromiseKit")
cpk.path = "Sources"
pkg.swiftLanguageVersions = [3, 4]
pkg.targets = [
    cpk,
    .testTarget(name: "Core", dependencies: ["CancelForPromiseKit"], path: "Tests/CorePromise"),
]
