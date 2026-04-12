// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VinslippMac",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "VinslippMac",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                // FirebaseMessaging requires a signed app bundle with entitlements.
                // Add it back when building via Xcode project with proper code signing.
                // .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
            ],
            path: "App",
            resources: [
                .process("Assets.xcassets"),
                .process("GoogleService-Info.plist"),
            ]
        ),
    ]
)
