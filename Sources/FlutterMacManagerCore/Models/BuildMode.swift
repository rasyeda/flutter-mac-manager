import Foundation

public enum BuildMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case debug
    case profile
    case release

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .profile: return "Profile"
        case .release: return "Release"
        }
    }
}

public enum BuildModeFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case debug
    case profile

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .debug: return "Debug"
        case .profile: return "Profile"
        }
    }

    public func matches(_ mode: BuildMode) -> Bool {
        switch self {
        case .all: return mode == .debug || mode == .profile
        case .debug: return mode == .debug
        case .profile: return mode == .profile
        }
    }
}

public enum AppSortOrder: String, CaseIterable, Sendable, Identifiable {
    case recent
    case largest
    case name

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .largest: return "Largest"
        case .name: return "Name"
        }
    }
}
