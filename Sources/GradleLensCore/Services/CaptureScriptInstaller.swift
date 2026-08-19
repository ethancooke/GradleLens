import Foundation

public struct CaptureInstallStatus: Sendable, Equatable {
    public let path: String
    public let installed: Bool
    public let matchesBundled: Bool

    public init(path: String, installed: Bool, matchesBundled: Bool) {
        self.path = path
        self.installed = installed
        self.matchesBundled = matchesBundled
    }
}

public struct CaptureScriptInstaller: Sendable {
    public static let fileName = "gradlelens.init.gradle.kts"

    private let homeDirectory: URL
    private let environment: [String: String]

    public init(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
    }

    public func installURL(
        environment: [String: String]? = nil
    ) -> URL {
        AppPaths.gradleUserHome(
            environment: environment ?? self.environment,
            homeDirectory: homeDirectory
        )
            .appendingPathComponent("init.d", isDirectory: true)
            .appendingPathComponent(Self.fileName)
    }

    public func status(
        environment: [String: String]? = nil
    ) -> CaptureInstallStatus {
        let url = installURL(environment: environment)
        let installed = FileManager.default.fileExists(atPath: url.path)
        let matches: Bool
        if installed, let onDisk = try? String(contentsOf: url, encoding: .utf8) {
            matches = onDisk == Self.bundledScript()
        } else {
            matches = false
        }
        return CaptureInstallStatus(path: url.path, installed: installed, matchesBundled: matches)
    }

    public func install(
        environment: [String: String]? = nil
    ) throws {
        let url = installURL(environment: environment)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.bundledScript().write(to: url, atomically: true, encoding: .utf8)
    }

    public func uninstall(
        environment: [String: String]? = nil
    ) throws {
        let url = installURL(environment: environment)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public static func bundledScript() -> String {
        if let url = Bundle.module.url(forResource: "gradlelens.init", withExtension: "gradle.kts"),
           let text = try? String(contentsOf: url, encoding: .utf8)
        {
            return text
        }
        if let url = Bundle.module.url(forResource: "gradlelens.init", withExtension: "gradle.kts", subdirectory: "Resources"),
           let text = try? String(contentsOf: url, encoding: .utf8)
        {
            return text
        }
        return embeddedFallback
    }

    // Used only if the SPM resource is missing (should not happen in a normal build).
    private static let embeddedFallback = """
        // GradleLens capture script missing from the application bundle.
        // Reinstall the app, or copy Sources/GradleLensCore/Resources/gradlelens.init.gradle.kts
        // to ~/.gradle/init.d/gradlelens.init.gradle.kts
        """
}
