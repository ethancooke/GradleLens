import Foundation

public struct GradleModule: Sendable, Hashable, Identifiable {
    public var id: String { path }
    /// Gradle path, e.g. `:app` or `:feature:home`.
    public let path: String
    /// Relative directory, e.g. `app` or `feature/home`.
    public let directory: String
    public let inferredTasks: [String]

    public init(path: String, directory: String, inferredTasks: [String] = []) {
        self.path = path
        self.directory = directory
        self.inferredTasks = inferredTasks
    }
}

public struct ProjectStructure: Sendable, Hashable {
    public let rootName: String
    public let modules: [GradleModule]
    public let includedBuilds: [String]
    public let gradleVersion: String?
    public let settingsFileName: String?

    public init(
        rootName: String,
        modules: [GradleModule],
        includedBuilds: [String],
        gradleVersion: String?,
        settingsFileName: String?
    ) {
        self.rootName = rootName
        self.modules = modules
        self.includedBuilds = includedBuilds
        self.gradleVersion = gradleVersion
        self.settingsFileName = settingsFileName
    }
}
