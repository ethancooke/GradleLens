import Foundation

public enum AppPaths: Sendable {
    public static func applicationSupportDirectory() throws -> URL {
        guard
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            throw GradleLensError.io("Application Support directory is unavailable.")
        }
        let dir = base.appendingPathComponent("GradleLens", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func defaultDatabaseURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("history.sqlite")
    }

    public static func gradleUserHome(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> URL {
        if let env = environment["GRADLE_USER_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        return homeDirectory.appendingPathComponent(".gradle", isDirectory: true)
    }

    public static func defaultBuildCacheDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> URL {
        gradleUserHome(environment: environment, homeDirectory: homeDirectory)
            .appendingPathComponent("caches", isDirectory: true)
            .appendingPathComponent("build-cache-1", isDirectory: true)
    }
}
