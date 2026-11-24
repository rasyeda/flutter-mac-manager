import Foundation

public struct ScanSettings: Codable, Equatable, Sendable {
    public var scanRoots: [String]
    public var scanDerivedData: Bool
    public var scanApplications: Bool
    public var moveToTrashByDefault: Bool

    public init(
        scanRoots: [String] = ScanSettings.defaultScanRoots(),
        scanDerivedData: Bool = true,
        scanApplications: Bool = false,
        moveToTrashByDefault: Bool = true
    ) {
        self.scanRoots = scanRoots
        self.scanDerivedData = scanDerivedData
        self.scanApplications = scanApplications
        self.moveToTrashByDefault = moveToTrashByDefault
    }

    public static func defaultScanRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String] {
        let candidates = ["Projects", "Developer", "Development", "StudioProjects", "src", "code"]
        let fm = FileManager.default
        let existing = candidates
            .map { homeDirectory.appendingPathComponent($0).path }
            .filter { fm.fileExists(atPath: $0) }
        if !existing.isEmpty {
            return existing
        }
        return [homeDirectory.appendingPathComponent("Projects").path]
    }
}

public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "com.fluttermacmanager.scanSettings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ScanSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ScanSettings.self, from: data) else {
            return ScanSettings()
        }
        return decoded
    }

    public func save(_ settings: ScanSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
