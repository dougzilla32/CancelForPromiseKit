// swift-tools-version:4.0
import PackageDescription

let pkg = Package(name: "CancelForPromiseKit")
pkg.products = [
    .library(name: "CancelForPromiseKit", targets: ["CancelForPromiseKit"]),
]
pkg.dependencies = [
    .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.3.4"),
]

let cpk: Target = .target(name: "CancelForPromiseKit")
cpk.path = "Sources"
cpk.dependencies = ["PromiseKit"]
pkg.swiftLanguageVersions = [3, 4]
pkg.targets = [
    cpk,
    .testTarget(name: "CPKCoreTests", dependencies: ["CancelForPromiseKit"], path: "Tests/CorePromise"),
]
