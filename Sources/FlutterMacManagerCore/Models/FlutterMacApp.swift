import Foundation

public enum DataLocationKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case container = "Container"
    case applicationSupport = "Application Support"
    case preferences = "Preferences"
    case caches = "Caches"
    case savedState = "Saved Application State"
    case httpStorages = "HTTP Storages"
    case derivedData = "DerivedData"

    public var id: String { rawValue }
}

public struct AppDataLocation: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: DataLocationKind
    public let url: URL
    public let sizeBytes: Int64
    public let isReadable: Bool

    public init(kind: DataLocationKind, url: URL, sizeBytes: Int64, isReadable: Bool = true) {
        self.id = "\(kind.rawValue):\(url.path)"
        self.kind = kind
        self.url = url
        self.sizeBytes = sizeBytes
        self.isReadable = isReadable
    }
}

public enum AppOrigin: String, Codable, Sendable {
    case projectBuild = "Project Build"
    case derivedData = "DerivedData"
    case applications = "Applications"
}

public struct FlutterMacApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let buildNumber: String
    public let mode: BuildMode
    public let origin: AppOrigin
    public let appURL: URL
    public let appSizeBytes: Int64
    public let lastModified: Date
    public let dataLocations: [AppDataLocation]
    public let derivedDataLocations: [AppDataLocation]
    public let runningPID: Int32?

    public init(
        name: String,
        bundleIdentifier: String,
        version: String,
        buildNumber: String,
        mode: BuildMode,
        origin: AppOrigin,
        appURL: URL,
        appSizeBytes: Int64,
        lastModified: Date,
        dataLocations: [AppDataLocation],
        derivedDataLocations: [AppDataLocation] = [],
        runningPID: Int32? = nil
    ) {
        self.id = appURL.standardizedFileURL.path
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.buildNumber = buildNumber
        self.mode = mode
        self.origin = origin
        self.appURL = appURL
        self.appSizeBytes = appSizeBytes
        self.lastModified = lastModified
        self.dataLocations = dataLocations
        self.derivedDataLocations = derivedDataLocations
        self.runningPID = runningPID
    }

    public var dataSizeBytes: Int64 {
        dataLocations.reduce(0) { $0 + $1.sizeBytes }
    }

    public var derivedDataSizeBytes: Int64 {
        derivedDataLocations.reduce(0) { $0 + $1.sizeBytes }
    }

    public var totalSizeBytes: Int64 {
        appSizeBytes + dataSizeBytes + derivedDataSizeBytes
    }

    public var isRunning: Bool {
        runningPID != nil
    }

    public var versionSummary: String {
        if version.isEmpty && buildNumber.isEmpty {
            return "Unknown"
        }
        if buildNumber.isEmpty || buildNumber == version {
            return version
        }
        return "\(version) (\(buildNumber))"
    }
}
