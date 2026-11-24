import Foundation
import XCTest
@testable import FlutterMacManagerCore

final class CleanupServiceTests: XCTestCase {
    private var tempHome: URL!

    override func setUpWithError() throws {
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlutterMacManagerCleanup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempHome = tempHome {
            try? FileManager.default.removeItem(at: tempHome)
        }
    }

    func testPathAllowlistGuardrails() {
        let service = CleanupService(homeDirectory: tempHome)

        // Allowed paths
        XCTAssertTrue(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Projects/app/build/macos/Build/Products/Debug/MyApp.app")
        ))
        XCTAssertTrue(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Projects/app/build/macos/Build/Products/Profile/MyApp.app")
        ))
        XCTAssertTrue(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Library/Containers/com.example.myapp")
        ))
        XCTAssertTrue(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Library/Preferences/com.example.myapp.plist")
        ))
        XCTAssertTrue(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Library/Developer/Xcode/DerivedData/Runner-abc123")
        ))

        // Blocked paths
        XCTAssertFalse(service.isAllowedDeletionPath(URL(fileURLWithPath: "/")))
        XCTAssertFalse(service.isAllowedDeletionPath(tempHome))
        XCTAssertFalse(service.isAllowedDeletionPath(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")))
        XCTAssertFalse(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Projects/app/build/macos/Build/Products/Release/MyApp.app")
        ))
        XCTAssertFalse(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Library/Containers")
        ))
        XCTAssertFalse(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        ))
        XCTAssertFalse(service.isAllowedDeletionPath(
            tempHome.appendingPathComponent("Documents/important.txt")
        ))
    }

    func testResetDataExecutesAndRespectsKeepPreferences() async throws {
        let fm = FileManager.default
        let containerURL = tempHome.appendingPathComponent("Library/Containers/com.example.testapp", isDirectory: true)
        let prefsURL = tempHome.appendingPathComponent("Library/Preferences/com.example.testapp.plist")
        try fm.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: prefsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("state".utf8).write(to: containerURL.appendingPathComponent("data.json"))
        try Data("prefs".utf8).write(to: prefsURL)

        let appURL = tempHome.appendingPathComponent("Projects/test/build/macos/Build/Products/Debug/TestApp.app", isDirectory: true)
        let app = FlutterMacApp(
            name: "TestApp",
            bundleIdentifier: "com.example.testapp",
            version: "1.0.0",
            buildNumber: "1",
            mode: .debug,
            origin: .projectBuild,
            appURL: appURL,
            appSizeBytes: 1000,
            lastModified: Date(),
            dataLocations: [
                AppDataLocation(kind: .container, url: containerURL, sizeBytes: 100),
                AppDataLocation(kind: .preferences, url: prefsURL, sizeBytes: 50)
            ]
        )

        let service = CleanupService(homeDirectory: tempHome)
        let plan = service.makeResetDataPlan(for: app, keepPreferences: true, moveToTrash: false)

        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items.first?.url, containerURL)
        XCTAssertTrue(plan.flushPreferencesBundleIDs.isEmpty)

        let result = await service.execute(plan: plan, stopRunningApps: false)
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.removedCount, 1)
        XCTAssertFalse(fm.fileExists(atPath: containerURL.path))
        XCTAssertTrue(fm.fileExists(atPath: prefsURL.path))
    }
}
