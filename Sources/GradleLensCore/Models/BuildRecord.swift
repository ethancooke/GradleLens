import Foundation

public enum BuildOutcome: String, Sendable, Codable, CaseIterable, Identifiable {
    case succeeded
    case failed
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        case .unknown: "Unknown"
        }
    }
}

public struct BuildRecord: Sendable, Identifiable, Hashable, Codable {
    public let id: UUID
    public let projectID: String
    public let startedAt: Date
    public let duration: TimeInterval
    public let outcome: BuildOutcome
    public let requestedTasks: [String]
    public let gradleVersion: String?
    public let profilePath: String?
    public let gitBranch: String?
    public let gitCommit: String?
    public let importedAt: Date

    public init(
        id: UUID = UUID(),
        projectID: String,
        startedAt: Date,
        duration: TimeInterval,
        outcome: BuildOutcome,
        requestedTasks: [String],
        gradleVersion: String? = nil,
        profilePath: String? = nil,
        gitBranch: String? = nil,
        gitCommit: String? = nil,
        importedAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.startedAt = startedAt
        self.duration = duration
        self.outcome = outcome
        self.requestedTasks = requestedTasks
        self.gradleVersion = gradleVersion
        self.profilePath = profilePath
        self.gitBranch = gitBranch
        self.gitCommit = gitCommit
        self.importedAt = importedAt
    }

    public var requestedTasksLabel: String {
        requestedTasks.isEmpty ? "(default tasks)" : requestedTasks.joined(separator: "  ")
    }

    public var profileURL: URL? {
        profilePath.map { URL(fileURLWithPath: $0) }
    }
}

public struct BuildQuery: Sendable, Equatable {
    public var search: String
    public var outcome: BuildOutcome?
    public var limit: Int

    public init(search: String = "", outcome: BuildOutcome? = nil, limit: Int = 500) {
        self.search = search
        self.outcome = outcome
        self.limit = limit
    }
}
