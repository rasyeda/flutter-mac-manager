import AppKit
import Foundation

public struct CleanupService: Sendable {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    // MARK: - Plan Builders

    public func makeResetDataPlan(
        for app: FlutterMacApp,
        keepPreferences: Bool,
        moveToTrash: Bool
    ) -> CleanupPlan {
        let filteredLocations = app.dataLocations.filter { loc in
            if keepPreferences && loc.kind == .preferences {
                return false
            }
            return true
        }

        let items = filteredLocations.map { loc in
            CleanupTargetItem(
                label: "\(loc.kind.rawValue) (\(app.bundleIdentifier))",
                url: loc.url,
                sizeBytes: loc.sizeBytes,
                kind: loc.kind,
                bundleIdentifier: app.bundleIdentifier
            )
        }

        let flushIDs = (!keepPreferences && !app.bundleIdentifier.isEmpty) ? [app.bundleIdentifier] : []

        return CleanupPlan(
            action: .resetData,
            title: "Reset Data for \(app.name)",
            apps: [app],
            items: items,
            flushPreferencesBundleIDs: flushIDs,
            moveToTrash: moveToTrash
        )
    }

    public func makeCleanBuildPlan(
        for app: FlutterMacApp,
        includeAppData: Bool,
        moveToTrash: Bool
    ) -> CleanupPlan {
        var items: [CleanupTargetItem] = [
            CleanupTargetItem(
                label: "\(app.name).app (\(app.mode.displayName))",
                url: app.appURL,
                sizeBytes: app.appSizeBytes
            )
        ]

        for dd in app.derivedDataLocations {
            items.append(
                CleanupTargetItem(
                    label: "DerivedData (\(dd.url.lastPathComponent))",
                    url: dd.url,
                    sizeBytes: dd.sizeBytes,
                    kind: .derivedData
                )
            )
        }

        var flushIDs: [String] = []
        if includeAppData {
            for loc in app.dataLocations {
                items.append(
                    CleanupTargetItem(
                        label: "\(loc.kind.rawValue) (\(app.bundleIdentifier))",
                        url: loc.url,
                        sizeBytes: loc.sizeBytes,
                        kind: loc.kind,
                        bundleIdentifier: app.bundleIdentifier
                    )
                )
            }
            if !app.bundleIdentifier.isEmpty {
                flushIDs.append(app.bundleIdentifier)
            }
        }

        return CleanupPlan(
            action: .cleanBuild,
            title: "Clean \(app.name) (\(app.mode.displayName))",
            apps: [app],
            items: deduplicate(items),
            flushPreferencesBundleIDs: flushIDs,
            moveToTrash: moveToTrash
        )
    }

    public func makeCleanStalePlan(
        from apps: [FlutterMacApp],
        olderThanDays days: Int,
        includeAppData: Bool,
        moveToTrash: Bool,
        now: Date = Date()
    ) -> CleanupPlan {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let staleApps = apps.filter { $0.lastModified < cutoff }

        var allItems: [CleanupTargetItem] = []
        var flushIDs = Set<String>()

        for app in staleApps {
            allItems.append(
                CleanupTargetItem(
                    label: "\(app.name).app (\(app.mode.displayName))",
                    url: app.appURL,
                    sizeBytes: app.appSizeBytes
                )
            )
            for dd in app.derivedDataLocations {
                allItems.append(
                    CleanupTargetItem(
                        label: "DerivedData (\(dd.url.lastPathComponent))",
                        url: dd.url,
                        sizeBytes: dd.sizeBytes,
                        kind: .derivedData
                    )
                )
            }
            if includeAppData {
                for loc in app.dataLocations {
                    allItems.append(
                        CleanupTargetItem(
                            label: "\(loc.kind.rawValue) (\(app.bundleIdentifier))",
                            url: loc.url,
                            sizeBytes: loc.sizeBytes,
                            kind: loc.kind,
                            bundleIdentifier: app.bundleIdentifier
                        )
                    )
                }
                if !app.bundleIdentifier.isEmpty {
                    flushIDs.insert(app.bundleIdentifier)
                }
            }
        }

        return CleanupPlan(
            action: .cleanStale,
            title: "Clean \(staleApps.count) Builds Older Than \(days) Days",
            apps: staleApps,
            items: deduplicate(allItems),
            flushPreferencesBundleIDs: Array(flushIDs),
            moveToTrash: moveToTrash
        )
    }

    // MARK: - Path Safety Guardrail

    /// Strictly verifies that a URL is safe to remove (inside Flutter Debug/Profile products, DerivedData, or ~/Library app data).
    public func isAllowedDeletionPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = homeDirectory.standardizedFileURL.path

        // Refuse root, home, or system paths
        if path == "/" || path == home || path.hasPrefix("/System/") || path.hasPrefix("/usr/") {
            return false
        }

        // 1. Flutter build Debug/Profile .app
        if url.pathExtension == "app" {
            let components = url.standardizedFileURL.pathComponents
            if let productsIdx = components.lastIndex(of: "Products"),
               productsIdx + 1 < components.count {
                let modeDir = components[productsIdx + 1].lowercased()
                if modeDir == "debug" || modeDir == "profile" {
                    return true
                }
            }
            // Allow Flutter Debug/Profile .app in /Applications or ~/Applications only if verified Flutter Debug/Profile
            if path.hasPrefix("/Applications/") || path.hasPrefix("\(home)/Applications/") {
                let mode = AppScanner.detectBuildMode(at: url)
                return AppScanner.isFlutterMacApp(at: url) && (mode == .debug || mode == .profile)
            }
            return false
        }

        // 2. DerivedData subfolder (must be a direct child of DerivedData, never DerivedData itself)
        let derivedDataPrefix = "\(home)/Library/Developer/Xcode/DerivedData/"
        if path.hasPrefix(derivedDataPrefix) {
            let remainder = String(path.dropFirst(derivedDataPrefix.count))
            return !remainder.isEmpty && !remainder.contains("..")
        }

        // 3. ~/Library/<AllowedCategory>/<bundleId>
        let allowedLibraryPrefixes = [
            "\(home)/Library/Containers/",
            "\(home)/Library/Application Support/",
            "\(home)/Library/Preferences/",
            "\(home)/Library/Caches/",
            "\(home)/Library/Saved Application State/",
            "\(home)/Library/HTTPStorages/"
        ]

        for prefix in allowedLibraryPrefixes {
            if path.hasPrefix(prefix) {
                let remainder = String(path.dropFirst(prefix.count))
                // Must target a specific single-segment entry (not empty, not nested traversal)
                return !remainder.isEmpty && !remainder.contains("/") && !remainder.contains("..")
            }
        }

        return false
    }

    // MARK: - Execution

    public func execute(plan: CleanupPlan, stopRunningApps: Bool) async -> CleanupResult {
        if stopRunningApps {
            await terminateRunningApps(plan.runningApps)
        }

        let fm = FileManager.default
        var removedCount = 0
        var reclaimedBytes: Int64 = 0
        var errors: [String] = []

        for item in plan.items {
            guard isAllowedDeletionPath(item.url) else {
                errors.append("Blocked unsafe path: \(item.url.path)")
                continue
            }
            guard fm.fileExists(atPath: item.url.path) else { continue }

            do {
                if plan.moveToTrash {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                } else {
                    try fm.removeItem(at: item.url)
                }
                removedCount += 1
                reclaimedBytes += item.sizeBytes
            } catch {
                errors.append("Failed to remove \(item.url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        for bundleID in plan.flushPreferencesBundleIDs {
            flushPreferencesCache(for: bundleID)
        }

        return CleanupResult(removedCount: removedCount, reclaimedBytes: reclaimedBytes, errors: errors)
    }

    @MainActor
    public func terminateRunningApps(_ apps: [FlutterMacApp]) {
        let targetPaths = Set(apps.map { $0.appURL.standardizedFileURL.path })
        for running in NSWorkspace.shared.runningApplications {
            if let url = running.bundleURL,
               targetPaths.contains(url.standardizedFileURL.path) {
                running.terminate()
            }
        }
    }

    private func flushPreferencesCache(for bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty, !bundleIdentifier.contains("/") else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["delete", bundleIdentifier]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    private func deduplicate(_ items: [CleanupTargetItem]) -> [CleanupTargetItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
