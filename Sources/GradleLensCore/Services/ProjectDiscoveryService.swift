import Foundation

public struct FolderScanOptions: Sendable {
    public var maxDepth: Int
    public var skipDirectoryNames: Set<String>

    public init(
        maxDepth: Int = 4,
        skipDirectoryNames: Set<String> = [
            ".git", ".gradle", "build", "node_modules", "DerivedData",
            ".build", ".swiftpm", "Pods", "Carthage", "vendor",
        ]
    ) {
        self.maxDepth = maxDepth
        self.skipDirectoryNames = skipDirectoryNames
    }
}

public actor ProjectDiscoveryService {
    private let ideReader: IDERecentProjectsReader

    public init(ideReader: IDERecentProjectsReader = IDERecentProjectsReader()) {
        self.ideReader = ideReader
    }

    public func project(at url: URL, source: ProjectSource, openedAt: Date = .now) throws -> GradleProject {
        let standardized = url.standardizedFileURL
        guard GradleProjectDetector.isGradleProject(at: standardized) else {
            throw GradleLensError.notAGradleProject(standardized.path)
        }
        return GradleProject(
            rootPath: standardized.path,
            name: GradleProjectDetector.displayName(at: standardized),
            lastOpenedAt: openedAt,
            lastIndexedAt: nil,
            source: source
        )
    }

    public func importIDERecents(
        applicationSupport: URL = IDERecentProjectsReader.defaultApplicationSupport(),
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()),
        now: Date = .now
    ) -> [GradleProject] {
        ideReader.read(applicationSupport: applicationSupport, homeDirectory: homeDirectory)
            .compactMap { item in
                let url = URL(fileURLWithPath: item.path, isDirectory: true)
                guard GradleProjectDetector.isGradleProject(at: url) else { return nil }
                return GradleProject(
                    rootPath: url.standardizedFileURL.path,
                    name: GradleProjectDetector.displayName(at: url),
                    lastOpenedAt: item.lastOpenedAt ?? now,
                    lastIndexedAt: nil,
                    source: .ideRecents
                )
            }
    }

    public func scan(folder url: URL, options: FolderScanOptions = FolderScanOptions(), now: Date = .now) -> [GradleProject] {
        var found: [GradleProject] = []
        visit(url: url.standardizedFileURL, depth: 0, options: options, now: now, into: &found)
        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func visit(
        url: URL,
        depth: Int,
        options: FolderScanOptions,
        now: Date,
        into found: inout [GradleProject]
    ) {
        guard depth <= options.maxDepth else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        if GradleProjectDetector.isGradleProject(at: url) {
            found.append(
                GradleProject(
                    rootPath: url.path,
                    name: GradleProjectDetector.displayName(at: url),
                    lastOpenedAt: now,
                    lastIndexedAt: nil,
                    source: .folderScan
                )
            )
        }

        guard depth < options.maxDepth else { return }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            if options.skipDirectoryNames.contains(child.lastPathComponent) { continue }
            visit(url: child, depth: depth + 1, options: options, now: now, into: &found)
        }
    }
}
