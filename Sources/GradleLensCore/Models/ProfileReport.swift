import Foundation

public struct NamedDuration: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let duration: TimeInterval

    public init(name: String, duration: TimeInterval) {
        self.name = name
        self.duration = duration
    }
}

public struct ProfileSummary: Sendable, Hashable {
    public let totalBuildTime: TimeInterval
    public let startup: TimeInterval
    public let settingsAndBuildSrc: TimeInterval
    public let loadingProjects: TimeInterval
    public let configuringProjects: TimeInterval
    public let artifactTransforms: TimeInterval
    public let taskExecution: TimeInterval

    public init(
        totalBuildTime: TimeInterval,
        startup: TimeInterval,
        settingsAndBuildSrc: TimeInterval,
        loadingProjects: TimeInterval,
        configuringProjects: TimeInterval,
        artifactTransforms: TimeInterval,
        taskExecution: TimeInterval
    ) {
        self.totalBuildTime = totalBuildTime
        self.startup = startup
        self.settingsAndBuildSrc = settingsAndBuildSrc
        self.loadingProjects = loadingProjects
        self.configuringProjects = configuringProjects
        self.artifactTransforms = artifactTransforms
        self.taskExecution = taskExecution
    }

    public var phases: [NamedDuration] {
        [
            NamedDuration(name: "Startup", duration: startup),
            NamedDuration(name: "Settings and buildSrc", duration: settingsAndBuildSrc),
            NamedDuration(name: "Loading Projects", duration: loadingProjects),
            NamedDuration(name: "Configuring Projects", duration: configuringProjects),
            NamedDuration(name: "Artifact Transforms", duration: artifactTransforms),
            NamedDuration(name: "Task Execution", duration: taskExecution),
        ]
    }
}

public enum TaskResult: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case executed
    case upToDate
    case fromCache
    case skipped
    case failed
    case noWork
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .executed: "Executed"
        case .upToDate: "UP-TO-DATE"
        case .fromCache: "FROM-CACHE"
        case .skipped: "SKIPPED"
        case .failed: "FAILED"
        case .noWork: "Did No Work"
        case .unknown: "Unknown"
        }
    }

    public static func parse(_ raw: String) -> TaskResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .executed }
        if trimmed == "(total)" { return .unknown }
        let upper = trimmed.uppercased()
        if upper.contains("FAIL") { return .failed }
        if upper.contains("FROM-CACHE") || upper.contains("FROM_CACHE") { return .fromCache }
        if upper.contains("UP-TO-DATE") || upper.contains("UP TO DATE") { return .upToDate }
        if upper.contains("NO-SOURCE") || upper.contains("NO SOURCE") { return .skipped }
        if upper.contains("SKIP") { return .skipped }
        if upper.contains("DID NO WORK") || upper.contains("NO WORK") { return .noWork }
        return .unknown
    }
}

public struct ProfileTask: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public let path: String
    public let duration: TimeInterval
    public let result: TaskResult
    public let rawResult: String
    public let startOffset: TimeInterval?

    public init(
        path: String,
        duration: TimeInterval,
        result: TaskResult,
        rawResult: String = "",
        startOffset: TimeInterval? = nil
    ) {
        self.path = path
        self.duration = duration
        self.result = result
        self.rawResult = rawResult
        self.startOffset = startOffset
    }
}

public struct ProfileReport: Sendable, Hashable {
    public let sourcePath: String
    public let startedAt: Date
    public let requestedTasks: [String]
    public let summary: ProfileSummary
    public let configuration: [NamedDuration]
    public let dependencyResolution: [NamedDuration]
    public let artifactTransforms: [NamedDuration]
    public let projectTotals: [NamedDuration]
    public let tasks: [ProfileTask]
    public let declaredOutcome: BuildOutcome?
    public let hasStartOffsets: Bool

    public init(
        sourcePath: String,
        startedAt: Date,
        requestedTasks: [String],
        summary: ProfileSummary,
        configuration: [NamedDuration],
        dependencyResolution: [NamedDuration],
        artifactTransforms: [NamedDuration],
        projectTotals: [NamedDuration],
        tasks: [ProfileTask],
        declaredOutcome: BuildOutcome? = nil
    ) {
        self.sourcePath = sourcePath
        self.startedAt = startedAt
        self.requestedTasks = requestedTasks
        self.summary = summary
        self.configuration = configuration
        self.dependencyResolution = dependencyResolution
        self.artifactTransforms = artifactTransforms
        self.projectTotals = projectTotals
        self.tasks = tasks
        self.declaredOutcome = declaredOutcome
        self.hasStartOffsets = tasks.contains { $0.startOffset != nil }
    }

    public var outcome: BuildOutcome {
        if let declaredOutcome { return declaredOutcome }
        return tasks.contains(where: { $0.result == .failed }) ? .failed : .succeeded
    }

    public var taskCountsByResult: [TaskResult: Int] {
        var counts: [TaskResult: Int] = [:]
        for task in tasks {
            counts[task.result, default: 0] += 1
        }
        return counts
    }

    public var tasksByDuration: [ProfileTask] {
        tasks.sorted { $0.duration > $1.duration }
    }

    public var sourceURL: URL {
        URL(fileURLWithPath: sourcePath)
    }
}

public struct BuildDetail: Sendable, Hashable {
    public let record: BuildRecord
    public let report: ProfileReport?
    public let scan: LocalScan?

    public init(record: BuildRecord, report: ProfileReport?, scan: LocalScan? = nil) {
        self.record = record
        self.report = report
        self.scan = scan
    }
}
