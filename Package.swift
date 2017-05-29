import PackageDescription

let package = Package(
    name: "CliRunnable",
    dependencies: [.Package(url: "https://github.com/behrang/YamlSwift.git", versions: Version(0,0,0)..<Version(10,0,0))]
)
