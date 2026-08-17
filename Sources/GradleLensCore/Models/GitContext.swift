import Foundation

public struct GitCommit: Sendable, Hashable, Identifiable {
    public var id: String { sha }
    public let sha: String
    public let author: String
    public let date: Date
    public let subject: String

    public init(sha: String, author: String, date: Date, subject: String) {
        self.sha = sha
        self.author = author
        self.date = date
        self.subject = subject
    }

    public var shortSHA: String {
        String(sha.prefix(7))
    }
}

public struct GitContext: Sendable, Hashable {
    public let isRepository: Bool
    public let branch: String?
    public let headSHA: String?
    public let isDirty: Bool
    public let dirtyFileCount: Int
    public let recentCommits: [GitCommit]

    public init(
        isRepository: Bool,
        branch: String? = nil,
        headSHA: String? = nil,
        isDirty: Bool = false,
        dirtyFileCount: Int = 0,
        recentCommits: [GitCommit] = []
    ) {
        self.isRepository = isRepository
        self.branch = branch
        self.headSHA = headSHA
        self.isDirty = isDirty
        self.dirtyFileCount = dirtyFileCount
        self.recentCommits = recentCommits
    }

    public static let notARepository = GitContext(isRepository: false)

    public var shortHead: String? {
        headSHA.map { String($0.prefix(7)) }
    }
}
