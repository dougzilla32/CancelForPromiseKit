// swift-tools-version:4.0

import PackageDescription

let pkg = Package(name: "CancelForPromiseKit")
pkg.products = [
    .library(name: "CancelForPromiseKit", targets: ["CancelForPromiseKit"]),
]

let cpk: Target = .target(name: "CancelForPromiseKit")
cpk.path = "Sources"
cpk.swiftLanguageVersions = [3, 4]
cpk.targets = [
    cpk,
    .testTarget(name: "A+", dependencies: ["CancelForPromiseKit"]),
]
