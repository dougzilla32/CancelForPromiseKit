import PackageDescription

let package = Package(
    name: "CancelForPromiseKit",
    dependencies: [
        .Package(url: "https://github.com/mxcl/PromiseKit", majorVersion: 6)
    ],
    swiftLanguageVersions: [3, 4],
    exclude: [
		"Tests"
    ]
)
