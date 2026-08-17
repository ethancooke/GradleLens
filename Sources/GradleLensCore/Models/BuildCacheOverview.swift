import Foundation

public struct CacheEntry: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let byteCount: Int64
    public let modifiedAt: Date

    public init(name: String, byteCount: Int64, modifiedAt: Date) {
        self.name = name
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
    }
}

public struct BuildCacheOverview: Sendable, Hashable {
    public let path: String
    public let exists: Bool
    public let entryCount: Int
    public let totalBytes: Int64
    public let oldestEntry: Date?
    public let newestEntry: Date?
    public let largestEntries: [CacheEntry]

    public init(
        path: String,
        exists: Bool,
        entryCount: Int,
        totalBytes: Int64,
        oldestEntry: Date?,
        newestEntry: Date?,
        largestEntries: [CacheEntry]
    ) {
        self.path = path
        self.exists = exists
        self.entryCount = entryCount
        self.totalBytes = totalBytes
        self.oldestEntry = oldestEntry
        self.newestEntry = newestEntry
        self.largestEntries = largestEntries
    }

    public var pathURL: URL {
        URL(fileURLWithPath: path)
    }

    public var averageBytes: Int64 {
        guard entryCount > 0 else { return 0 }
        return totalBytes / Int64(entryCount)
    }
}
