// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Triovel",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/powersync-ja/powersync-swift.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Triovel",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "PowerSync", package: "powersync-swift"),
            ],
            path: "Triovel"
        ),
    ]
)
