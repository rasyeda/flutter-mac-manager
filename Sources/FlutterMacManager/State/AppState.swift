import AppKit
import FlutterMacManagerCore
import Foundation
import SwiftUI

struct StatusBanner: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

enum PendingCleanupRequest: Identifiable {
    case resetData(FlutterMacApp)
    case cleanBuild(FlutterMacApp)
    case cleanStale(days: Int)

    var id: String {
        switch self {
        case .resetData(let app): return "reset:\(app.id)"
        case .cleanBuild(let app): return "clean:\(app.id)"
        case .cleanStale(let days): return "stale:\(days)"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var apps: [FlutterMacApp] = []
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date?
    @Published var searchText: String = ""
    @Published var modeFilter: BuildModeFilter = .all
    @Published var sortOrder: AppSortOrder = .recent
    @Published var expandedAppID: String?
    @Published var showingSettings: Bool = false
    @Published var pendingRequest: PendingCleanupRequest?
    @Published var statusBanner: StatusBanner?
    @Published var settings: ScanSettings {
        didSet {
            settingsStore.save(settings)
        }
    }

    private let scanner: AppScanner
    let cleanupService: CleanupService
    private let settingsStore: SettingsStore

    init(
        scanner: AppScanner = AppScanner(),
        cleanupService: CleanupService = CleanupService(),
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.scanner = scanner
        self.cleanupService = cleanupService
        self.settingsStore = settingsStore
        self.settings = settingsStore.load()
    }

    var filteredApps: [FlutterMacApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = apps.filter { app in
            guard modeFilter.matches(app.mode) else { return false }
            if query.isEmpty { return true }
            return app.name.lowercased().contains(query)
                || app.bundleIdentifier.lowercased().contains(query)
                || app.appURL.path.lowercased().contains(query)
        }

        switch sortOrder {
        case .recent:
            return filtered.sorted { $0.lastModified > $1.lastModified }
        case .largest:
            return filtered.sorted { $0.totalSizeBytes > $1.totalSizeBytes }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Bundle IDs shared by more than one discovered build (e.g. Debug + Profile of the same project).
    var sharedBundleIDs: Set<String> {
        var counts: [String: Int] = [:]
        for app in apps where !app.bundleIdentifier.isEmpty {
            counts[app.bundleIdentifier, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    var totalBytes: Int64 {
        var seenDataPaths = Set<String>()
        var total: Int64 = 0
        for app in filteredApps {
            total += app.appSizeBytes
            for loc in app.dataLocations + app.derivedDataLocations {
                if seenDataPaths.insert(loc.url.standardizedFileURL.path).inserted {
                    total += loc.sizeBytes
                }
            }
        }
        return total
    }

    var menuBarTitle: String {
        apps.isEmpty ? "" : "\(apps.count)"
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        let currentSettings = settings
        let discovered = await scanner.scan(settings: currentSettings)
        apps = discovered
        lastScanDate = Date()
        isScanning = false
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func quitApp(_ app: FlutterMacApp) {
        cleanupService.terminateRunningApps([app])
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await refresh()
        }
    }

    func execute(plan: CleanupPlan, stopRunningApps: Bool) async {
        let result = await cleanupService.execute(plan: plan, stopRunningApps: stopRunningApps)
        if result.isSuccess {
            let verb = plan.moveToTrash ? "Moved to Trash" : "Deleted"
            let sizeText = ByteFormatting.format(result.reclaimedBytes)
            statusBanner = StatusBanner(
                message: "\(verb): \(result.removedCount) item(s) (\(sizeText))",
                isError: false
            )
        } else {
            statusBanner = StatusBanner(
                message: result.errors.first ?? "Cleanup completed with errors.",
                isError: true
            )
        }
        pendingRequest = nil
        await refresh()
    }

    func addScanRoot(_ path: String) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        if !settings.scanRoots.contains(normalized) {
            settings.scanRoots.append(normalized)
        }
    }

    func removeScanRoot(_ path: String) {
        settings.scanRoots.removeAll { $0 == path }
    }
}
