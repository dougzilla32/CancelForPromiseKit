// swift-tools-version:4.0

import PackageDescription

let pkg = Package(
    name: "CancelForPromiseKit",
    products: [
        .library(name: "CancelForPromiseKit", targets: ["CancelForPromiseKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit", from: "6.1.0")
    ],
    swiftLanguageVersions: [3, 4]
)

let cpk: Target = .target(
    name: "CancelForPromiseKit",
    dependencies: ["PromiseKit"],
    path: "Sources"
)
pkg.targets = [
    cpk,
    .testTarget(name: "CPKCore", dependencies: ["CancelForPromiseKit", "PromiseKit"], path: "Tests/CorePromise"),
]
