import Foundation

public enum ProjectSource: String, Sendable, Codable, Hashable {
    case manual
    case ideRecents
    case folderScan
}

public struct GradleProject: Sendable, Identifiable, Hashable, Codable {
    public var id: String { rootPath }
    public let rootPath: String
    public let name: String
    public let lastOpenedAt: Date
    public let lastIndexedAt: Date?
    public let source: ProjectSource

    public init(
        rootPath: String,
        name: String,
        lastOpenedAt: Date,
        lastIndexedAt: Date? = nil,
        source: ProjectSource
    ) {
        self.rootPath = rootPath
        self.name = name
        self.lastOpenedAt = lastOpenedAt
        self.lastIndexedAt = lastIndexedAt
        self.source = source
    }

    public var rootURL: URL {
        URL(fileURLWithPath: rootPath)
    }

    public func touchingOpened(at date: Date = .now) -> GradleProject {
        GradleProject(
            rootPath: rootPath,
            name: name,
            lastOpenedAt: date,
            lastIndexedAt: lastIndexedAt,
            source: source
        )
    }

    public func touchingIndexed(at date: Date = .now) -> GradleProject {
        GradleProject(
            rootPath: rootPath,
            name: name,
            lastOpenedAt: lastOpenedAt,
            lastIndexedAt: date,
            source: source
        )
    }
}
