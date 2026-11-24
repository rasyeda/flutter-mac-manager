import Foundation

public struct DataFootprintService: Sendable {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    public var libraryURL: URL {
        homeDirectory.appendingPathComponent("Library", isDirectory: true)
    }

    /// Resolves existing ~/Library data locations associated with a macOS bundle identifier.
    public func dataLocations(for bundleIdentifier: String) -> [AppDataLocation] {
        guard !bundleIdentifier.isEmpty,
              !bundleIdentifier.contains("/"),
              !bundleIdentifier.contains("..") else {
            return []
        }

        let candidates: [(DataLocationKind, URL)] = [
            (.container, libraryURL.appendingPathComponent("Containers/\(bundleIdentifier)", isDirectory: true)),
            (.applicationSupport, libraryURL.appendingPathComponent("Application Support/\(bundleIdentifier)", isDirectory: true)),
            (.preferences, libraryURL.appendingPathComponent("Preferences/\(bundleIdentifier).plist", isDirectory: false)),
            (.caches, libraryURL.appendingPathComponent("Caches/\(bundleIdentifier)", isDirectory: true)),
            (.savedState, libraryURL.appendingPathComponent("Saved Application State/\(bundleIdentifier).savedState", isDirectory: true)),
            (.httpStorages, libraryURL.appendingPathComponent("HTTPStorages/\(bundleIdentifier)", isDirectory: true))
        ]

        let fm = FileManager.default
        var results: [AppDataLocation] = []

        for (kind, url) in candidates {
            guard fm.fileExists(atPath: url.path) else { continue }
            let readable = fm.isReadableFile(atPath: url.path)
            let size = readable ? Self.directoryOrFileSize(at: url) : 0
            results.append(AppDataLocation(kind: kind, url: url, sizeBytes: size, isReadable: readable))
        }

        return results
    }

    /// Calculates allocated size of a file or directory tree without traversing symlinks.
    public static func directoryOrFileSize(at url: URL) -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        if let values = try? url.resourceValues(forKeys: resourceKeys),
           values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
        }

        // Descend into packages (e.g. .app bundles) while skipping symlinks.
        return calculateSizeDescendingPackages(at: url, keys: resourceKeys)
    }

    private static func calculateSizeDescendingPackages(at url: URL, keys: Set<URLResourceKey>) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { continue }
            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
