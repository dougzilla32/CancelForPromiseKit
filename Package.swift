// swift-tools-version:4.0

import PackageDescription

let pkg = Package(name: "CancellablePromiseKit")
pkg.products = [
    .library(name: "CancellablePromiseKit", targets: ["CancellablePromiseKit"]),
]

let cpk: Target = .target(name: "CancellablePromiseKit")
cpk.path = "Sources"
cpk.swiftLanguageVersions = [3, 4]
cpk.targets = [
    cpk,
    .testTarget(name: "A+", dependencies: ["CancellablePromiseKit"]),
]
