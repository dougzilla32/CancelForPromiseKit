import PackageDescription

let package = Package(
    name: "CancelForPromiseKit",
    dependencies: [
        .Package(url: "https://github.com/mxcl/PromiseKit.git", majorVersion: 6, minor: 3)
    ],
    swiftLanguageVersions: [3, 4]
)
