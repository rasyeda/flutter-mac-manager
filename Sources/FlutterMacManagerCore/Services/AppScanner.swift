import AppKit
import Foundation

public struct AppScanner: Sendable {
    public let homeDirectory: URL
    public let footprintService: DataFootprintService

    private static let prunedDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", ".dart_tool", ".pub-cache", ".fvm",
        "node_modules", "Pods", ".symlinks", "ephemeral",
        ".build", "DerivedData", "xcuserdata", "build_artifacts",
        "android", "ios", "web", "linux", "windows", "test"
    ]

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        footprintService: DataFootprintService? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.footprintService = footprintService ?? DataFootprintService(homeDirectory: homeDirectory)
    }

    public func scan(settings: ScanSettings) async -> [FlutterMacApp] {
        let runningPIDs = await MainActor.run { Self.currentRunningPIDsByBundlePath() }

        var candidates: [(URL, AppOrigin)] = []

        for rootPath in settings.scanRoots {
            let expanded = (rootPath as NSString).expandingTildeInPath
            let rootURL = URL(fileURLWithPath: expanded, isDirectory: true)
            let found = findProjectBuildApps(under: rootURL)
            candidates.append(contentsOf: found.map { ($0, .projectBuild) })
        }

        if settings.scanDerivedData {
            let derivedDataURL = homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
            let found = findDerivedDataApps(under: derivedDataURL)
            candidates.append(contentsOf: found.map { ($0, .derivedData) })
        }

        if settings.scanApplications {
            let appDirs = [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                homeDirectory.appendingPathComponent("Applications", isDirectory: true)
            ]
            for dir in appDirs {
                let found = findTopLevelApps(in: dir)
                candidates.append(contentsOf: found.map { ($0, .applications) })
            }
        }

        // Deduplicate by standardized path
        var seen = Set<String>()
        let uniqueCandidates = candidates.filter { url, _ in
            seen.insert(url.standardizedFileURL.path).inserted
        }

        let service = footprintService
        return await withTaskGroup(of: FlutterMacApp?.self) { group in
            for (appURL, origin) in uniqueCandidates {
                group.addTask {
                    Self.inspectBundle(
                        at: appURL,
                        origin: origin,
                        footprintService: service,
                        runningPIDs: runningPIDs
                    )
                }
            }

            var apps: [FlutterMacApp] = []
            for await app in group {
                if let app = app {
                    apps.append(app)
                }
            }
            return apps.sorted { $0.lastModified > $1.lastModified }
        }
    }

    // MARK: - Bundle Inspection

    public static func isFlutterMacApp(at appURL: URL) -> Bool {
        let frameworkURL = appURL.appendingPathComponent("Contents/Frameworks/FlutterMacOS.framework", isDirectory: true)
        return FileManager.default.fileExists(atPath: frameworkURL.path)
    }

    public static func detectBuildMode(at appURL: URL) -> BuildMode {
        let pathComponents = appURL.standardizedFileURL.pathComponents
        if let productsIdx = pathComponents.lastIndex(of: "Products"),
           productsIdx + 1 < pathComponents.count {
            let folder = pathComponents[productsIdx + 1].lowercased()
            if folder == "debug" || folder.hasPrefix("debug-") {
                return .debug
            }
            if folder == "profile" || folder.hasPrefix("profile-") {
                return .profile
            }
            if folder == "release" || folder.hasPrefix("release-") {
                return .release
            }
        }

        // Fallback: inspect bundle contents
        let kernelBlob = appURL.appendingPathComponent(
            "Contents/Frameworks/App.framework/Resources/flutter_assets/kernel_blob.bin"
        )
        if FileManager.default.fileExists(atPath: kernelBlob.path) {
            return .debug
        }

        let vmSnapshot = appURL.appendingPathComponent(
            "Contents/Frameworks/App.framework/Resources/flutter_assets/vm_snapshot_data"
        )
        if FileManager.default.fileExists(atPath: vmSnapshot.path) {
            return .debug
        }

        // Check FlutterMacOS binary for Observatory / VM Service symbols (present in Profile, stripped in Release)
        let flutterBinary = appURL.appendingPathComponent(
            "Contents/Frameworks/FlutterMacOS.framework/Versions/A/FlutterMacOS"
        )
        if let data = try? Data(contentsOf: flutterBinary, options: [.mappedIfSafe]) {
            let marker = Data("Observatory listening on".utf8)
            let vmServiceMarker = Data("Dart VM service is listening on".utf8)
            if data.range(of: marker) != nil || data.range(of: vmServiceMarker) != nil {
                return .profile
            }
        }

        return .release
    }

    public static func inspectBundle(
        at appURL: URL,
        origin: AppOrigin,
        footprintService: DataFootprintService,
        runningPIDs: [String: Int32] = [:]
    ) -> FlutterMacApp? {
        guard isFlutterMacApp(at: appURL) else { return nil }

        let mode = detectBuildMode(at: appURL)
        guard mode == .debug || mode == .profile else { return nil }

        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let bundleID = (plist["CFBundleIdentifier"] as? String) ?? ""
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let version = (plist["CFBundleShortVersionString"] as? String) ?? ""
        let buildNumber = (plist["CFBundleVersion"] as? String) ?? ""

        let appSize = DataFootprintService.directoryOrFileSize(at: appURL)
        let modDate = (try? appURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let dataLocations = footprintService.dataLocations(for: bundleID)

        var derivedLocations: [AppDataLocation] = []
        if origin == .derivedData,
           let ddRoot = derivedDataProjectRoot(for: appURL) {
            let ddSize = DataFootprintService.directoryOrFileSize(at: ddRoot)
            derivedLocations.append(AppDataLocation(kind: .derivedData, url: ddRoot, sizeBytes: ddSize))
        }

        let runningPID = runningPIDs[appURL.standardizedFileURL.path]

        return FlutterMacApp(
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            buildNumber: buildNumber,
            mode: mode,
            origin: origin,
            appURL: appURL,
            appSizeBytes: appSize,
            lastModified: modDate,
            dataLocations: dataLocations,
            derivedDataLocations: derivedLocations,
            runningPID: runningPID
        )
    }

    private static func derivedDataProjectRoot(for appURL: URL) -> URL? {
        let components = appURL.standardizedFileURL.pathComponents
        guard let ddIdx = components.lastIndex(of: "DerivedData"),
              ddIdx + 1 < components.count else {
            return nil
        }
        let prefix = components[0...(ddIdx + 1)]
        return NSURL.fileURL(withPathComponents: Array(prefix))
    }

    // MARK: - Directory Walkers

    private func findProjectBuildApps(under rootURL: URL) -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: rootURL.path) else { return [] }

        var results: [URL] = []
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .nameKey]

        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values.isDirectory == true else { continue }

            let name = values.name ?? url.lastPathComponent

            if Self.prunedDirectoryNames.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            if name == "build" {
                let productsURL = url.appendingPathComponent("macos/Build/Products", isDirectory: true)
                if fm.fileExists(atPath: productsURL.path) {
                    results.append(contentsOf: collectAppsInProducts(productsURL))
                }
                enumerator.skipDescendants()
                continue
            }

            if name.hasSuffix(".app") || name.hasSuffix(".xcodeproj") || name.hasSuffix(".xcworkspace") {
                enumerator.skipDescendants()
                continue
            }
        }

        return results
    }

    private func findDerivedDataApps(under derivedDataURL: URL) -> [URL] {
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: derivedDataURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [URL] = []
        for dir in projectDirs {
            let productsURL = dir.appendingPathComponent("Build/Products", isDirectory: true)
            if fm.fileExists(atPath: productsURL.path) {
                results.append(contentsOf: collectAppsInProducts(productsURL))
            }
        }
        return results
    }

    private func collectAppsInProducts(_ productsURL: URL) -> [URL] {
        let fm = FileManager.default
        var apps: [URL] = []
        for sub in ["Debug", "Profile"] {
            let modeURL = productsURL.appendingPathComponent(sub, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(
                at: modeURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "app" {
                apps.append(entry)
            }
        }
        return apps
    }

    private func findTopLevelApps(in directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries.filter { $0.pathExtension == "app" }
    }

    @MainActor
    private static func currentRunningPIDsByBundlePath() -> [String: Int32] {
        var map: [String: Int32] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let bundleURL = app.bundleURL {
                map[bundleURL.standardizedFileURL.path] = app.processIdentifier
            }
        }
        return map
    }
}
