// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Meme Creator",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Meme Creator",
            targets: ["App"],
            displayVersion: "2.0",
            bundleVersion: "2",
            appIcon: .asset("AppIcon"),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .outgoingNetworkConnections(),
                .photoLibrary(purposeString: "Save and import memes to your photo library")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "App",
            path: "App"
        )
    ]
)
