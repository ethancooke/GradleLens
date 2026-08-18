import Foundation

public struct LocalScanGit: Sendable, Hashable {
    public let branch: String?
    public let commit: String?
    public let dirty: Bool?

    public init(branch: String?, commit: String?, dirty: Bool?) {
        self.branch = branch
        self.commit = commit
        self.dirty = dirty
    }
}

public struct LocalScan: Sendable, Hashable {
    public let sourcePath: String
    public let schemaVersion: Int
    public let startedAt: Date
    public let finishedAt: Date?
    public let duration: TimeInterval
    public let outcome: BuildOutcome
    public let requestedTasks: [String]
    public let excludedTasks: [String]
    public let gradleVersion: String?
    public let configurationCacheRequested: Bool?
    public let git: LocalScanGit?
    public let taskExecution: TimeInterval?
    public let tasks: [ProfileTask]

    public init(
        sourcePath: String,
        schemaVersion: Int,
        startedAt: Date,
        finishedAt: Date?,
        duration: TimeInterval,
        outcome: BuildOutcome,
        requestedTasks: [String],
        excludedTasks: [String],
        gradleVersion: String?,
        configurationCacheRequested: Bool?,
        git: LocalScanGit?,
        taskExecution: TimeInterval?,
        tasks: [ProfileTask]
    ) {
        self.sourcePath = sourcePath
        self.schemaVersion = schemaVersion
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.duration = duration
        self.outcome = outcome
        self.requestedTasks = requestedTasks
        self.excludedTasks = excludedTasks
        self.gradleVersion = gradleVersion
        self.configurationCacheRequested = configurationCacheRequested
        self.git = git
        self.taskExecution = taskExecution
        self.tasks = tasks
    }

    public var sourceURL: URL {
        URL(fileURLWithPath: sourcePath)
    }
}

public enum CaptureMerge {
    public static func report(profile: ProfileReport?, scan: LocalScan?) -> ProfileReport? {
        switch (profile, scan) {
        case (nil, nil):
            return nil
        case let (profile?, nil):
            return profile
        case let (nil, scan?):
            return ProfileReport(
                sourcePath: scan.sourcePath,
                startedAt: scan.startedAt,
                requestedTasks: scan.requestedTasks,
                summary: ProfileSummary(
                    totalBuildTime: scan.duration,
                    startup: 0,
                    settingsAndBuildSrc: 0,
                    loadingProjects: 0,
                    configuringProjects: 0,
                    artifactTransforms: 0,
                    taskExecution: scan.taskExecution ?? scan.tasks.reduce(0) { $0 + $1.duration }
                ),
                configuration: [],
                dependencyResolution: [],
                artifactTransforms: [],
                projectTotals: [],
                tasks: scan.tasks,
                declaredOutcome: scan.outcome
            )
        case let (profile?, scan?):
            return ProfileReport(
                sourcePath: scan.sourcePath,
                startedAt: scan.startedAt,
                requestedTasks: scan.requestedTasks.isEmpty ? profile.requestedTasks : scan.requestedTasks,
                summary: ProfileSummary(
                    totalBuildTime: scan.duration > 0 ? scan.duration : profile.summary.totalBuildTime,
                    startup: profile.summary.startup,
                    settingsAndBuildSrc: profile.summary.settingsAndBuildSrc,
                    loadingProjects: profile.summary.loadingProjects,
                    configuringProjects: profile.summary.configuringProjects,
                    artifactTransforms: profile.summary.artifactTransforms,
                    taskExecution: profile.summary.taskExecution > 0
                        ? profile.summary.taskExecution
                        : (scan.taskExecution ?? profile.summary.taskExecution)
                ),
                configuration: profile.configuration,
                dependencyResolution: profile.dependencyResolution,
                artifactTransforms: profile.artifactTransforms,
                projectTotals: profile.projectTotals,
                tasks: scan.tasks.isEmpty ? profile.tasks : scan.tasks,
                declaredOutcome: scan.outcome
            )
        }
    }
}
