import Foundation
import XCTest
@testable import FlutterMacManagerCore

final class AppScannerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlutterMacManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testScanDiscoversDebugAndProfileAndSkipsReleaseAndNonFlutter() async throws {
        let fakeHome = tempDir.appendingPathComponent("Home", isDirectory: true)
        let projects = fakeHome.appendingPathComponent("Projects/demo_app", isDirectory: true)

        // 1. Debug Flutter app
        let debugApp = projects.appendingPathComponent("build/macos/Build/Products/Debug/DemoApp.app", isDirectory: true)
        try createMockApp(at: debugApp, bundleID: "com.example.demo", name: "DemoApp", isFlutter: true, includeKernelBlob: true)

        // 2. Profile Flutter app
        let profileApp = projects.appendingPathComponent("build/macos/Build/Products/Profile/DemoApp.app", isDirectory: true)
        try createMockApp(at: profileApp, bundleID: "com.example.demo", name: "DemoApp", isFlutter: true, includeKernelBlob: false)

        // 3. Release Flutter app (should be excluded)
        let releaseApp = projects.appendingPathComponent("build/macos/Build/Products/Release/DemoApp.app", isDirectory: true)
        try createMockApp(at: releaseApp, bundleID: "com.example.demo", name: "DemoApp", isFlutter: true, includeKernelBlob: false)

        // 4. Non-Flutter macOS app in Debug (should be excluded)
        let nativeApp = projects.appendingPathComponent("build/macos/Build/Products/Debug/NativeHelper.app", isDirectory: true)
        try createMockApp(at: nativeApp, bundleID: "com.example.native", name: "NativeHelper", isFlutter: false, includeKernelBlob: false)

        // 5. Mock ~/Library/Containers & Preferences for com.example.demo
        let containerURL = fakeHome.appendingPathComponent("Library/Containers/com.example.demo/Data", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: 4096).write(to: containerURL.appendingPathComponent("cache.db"))

        let prefsURL = fakeHome.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefsURL, withIntermediateDirectories: true)
        try Data(repeating: 0x01, count: 256).write(to: prefsURL.appendingPathComponent("com.example.demo.plist"))

        let scanner = AppScanner(homeDirectory: fakeHome)
        let settings = ScanSettings(
            scanRoots: [fakeHome.appendingPathComponent("Projects").path],
            scanDerivedData: false,
            scanApplications: false,
            moveToTrashByDefault: true
        )

        let results = await scanner.scan(settings: settings)
        XCTAssertEqual(results.count, 2)

        let modes = Set(results.map(\.mode))
        XCTAssertEqual(modes, [.debug, .profile])

        for app in results {
            XCTAssertEqual(app.bundleIdentifier, "com.example.demo")
            XCTAssertEqual(app.name, "DemoApp")
            XCTAssertEqual(app.dataLocations.count, 2)
            XCTAssertGreaterThan(app.dataSizeBytes, 0)
        }
    }

    func testDetectBuildModeFromBundleContentsOutsideProductsFolder() throws {
        let customDir = tempDir.appendingPathComponent("CustomApps", isDirectory: true)
        let debugApp = customDir.appendingPathComponent("CopiedDebug.app", isDirectory: true)
        try createMockApp(at: debugApp, bundleID: "com.example.copied", name: "CopiedDebug", isFlutter: true, includeKernelBlob: true)

        XCTAssertEqual(AppScanner.detectBuildMode(at: debugApp), .debug)
    }

    private func createMockApp(
        at appURL: URL,
        bundleID: String,
        name: String,
        isFlutter: Bool,
        includeKernelBlob: Bool
    ) throws {
        let fm = FileManager.default
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try fm.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        if isFlutter {
            let flutterFramework = contentsURL.appendingPathComponent("Frameworks/FlutterMacOS.framework", isDirectory: true)
            try fm.createDirectory(at: flutterFramework, withIntermediateDirectories: true)
        }

        if includeKernelBlob {
            let assets = contentsURL.appendingPathComponent("Frameworks/App.framework/Resources/flutter_assets", isDirectory: true)
            try fm.createDirectory(at: assets, withIntermediateDirectories: true)
            try Data("kernel".utf8).write(to: assets.appendingPathComponent("kernel_blob.bin"))
        }
    }
}
