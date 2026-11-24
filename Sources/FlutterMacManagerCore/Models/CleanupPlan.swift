import Foundation

public enum CleanupActionKind: String, Sendable {
    case resetData
    case cleanBuild
    case cleanStale
}

public struct CleanupTargetItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let url: URL
    public let sizeBytes: Int64
    public let kind: DataLocationKind?
    public let bundleIdentifier: String?

    public init(
        label: String,
        url: URL,
        sizeBytes: Int64,
        kind: DataLocationKind? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.id = url.standardizedFileURL.path
        self.label = label
        self.url = url
        self.sizeBytes = sizeBytes
        self.kind = kind
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct CleanupPlan: Identifiable, Sendable {
    public let id = UUID()
    public let action: CleanupActionKind
    public let title: String
    public let apps: [FlutterMacApp]
    public let items: [CleanupTargetItem]
    public let flushPreferencesBundleIDs: [String]
    public let moveToTrash: Bool

    public init(
        action: CleanupActionKind,
        title: String,
        apps: [FlutterMacApp],
        items: [CleanupTargetItem],
        flushPreferencesBundleIDs: [String],
        moveToTrash: Bool
    ) {
        self.action = action
        self.title = title
        self.apps = apps
        self.items = items
        self.flushPreferencesBundleIDs = flushPreferencesBundleIDs
        self.moveToTrash = moveToTrash
    }

    public var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    public var runningApps: [FlutterMacApp] {
        apps.filter { $0.isRunning }
    }
}

public struct CleanupResult: Sendable {
    public let removedCount: Int
    public let reclaimedBytes: Int64
    public let errors: [String]

    public init(removedCount: Int, reclaimedBytes: Int64, errors: [String]) {
        self.removedCount = removedCount
        self.reclaimedBytes = reclaimedBytes
        self.errors = errors
    }

    public var isSuccess: Bool { errors.isEmpty }
}

public enum ByteFormatting {
    public static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
