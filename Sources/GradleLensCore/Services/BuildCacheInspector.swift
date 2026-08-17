import Foundation

public actor BuildCacheInspector {
    public init() {}

    public func overview(
        at cacheDirectory: URL = AppPaths.defaultBuildCacheDirectory(),
        largestLimit: Int = 8
    ) -> BuildCacheOverview {
        var isDirectory: ObjCBool = false
        let path = cacheDirectory.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return BuildCacheOverview(
                path: path,
                exists: false,
                entryCount: 0,
                totalBytes: 0,
                oldestEntry: nil,
                newestEntry: nil,
                largestEntries: []
            )
        }

        let skipNames: Set<String> = [
            "gc.properties", "CACHEDIR.TAG", ".lock", "build-cache-1.lock",
        ]
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
        ]

        var entryCount = 0
        var totalBytes: Int64 = 0
        var oldest: Date?
        var newest: Date?
        var largest: [CacheEntry] = []

        if let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) {
            for case let file as URL in enumerator {
                if skipNames.contains(file.lastPathComponent) { continue }
                guard let values = try? file.resourceValues(forKeys: Set(keys)) else { continue }
                guard values.isRegularFile == true else { continue }
                let size = Int64(values.fileSize ?? 0)
                let modified = values.contentModificationDate ?? .distantPast
                entryCount += 1
                totalBytes += size
                if oldest == nil || modified < oldest! { oldest = modified }
                if newest == nil || modified > newest! { newest = modified }
                largest.append(
                    CacheEntry(name: file.lastPathComponent, byteCount: size, modifiedAt: modified)
                )
                if largest.count > largestLimit * 4 {
                    largest.sort { $0.byteCount > $1.byteCount }
                    largest = Array(largest.prefix(largestLimit))
                }
            }
        }

        largest.sort { $0.byteCount > $1.byteCount }
        largest = Array(largest.prefix(largestLimit))

        return BuildCacheOverview(
            path: path,
            exists: true,
            entryCount: entryCount,
            totalBytes: totalBytes,
            oldestEntry: oldest,
            newestEntry: newest,
            largestEntries: largest
        )
    }
}
