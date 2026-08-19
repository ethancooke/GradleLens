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
        // Never use Bundle.module. SwiftPM's generated accessor looks for
        // `<app>.app/GradleLens_GradleLensCore.bundle` and fatalErrors if that
        // path is missing — which is what a Contents/Resources layout does.
        if let text = script(fromCandidates: candidateScriptURLs()) {
            return text
        }
        return embeddedFallback
    }

    static func script(fromCandidates urls: [URL]) -> String? {
        for url in urls {
            if let text = try? String(contentsOf: url, encoding: .utf8), looksLikeCaptureScript(text) {
                return text
            }
        }
        return nil
    }

    static func candidateScriptURLs(main: Bundle = .main, sourceFilePath: String = #filePath) -> [URL] {
        let fileName = Self.fileName
        let bundleDir = "GradleLens_GradleLensCore.bundle"
        var urls: [URL] = []

        if let resource = main.url(forResource: "gradlelens.init", withExtension: "gradle.kts") {
            urls.append(resource)
        }
        if let resourceURL = main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(fileName))
            urls.append(resourceURL.appendingPathComponent(bundleDir).appendingPathComponent(fileName))
        }
        urls.append(main.bundleURL.appendingPathComponent(bundleDir).appendingPathComponent(fileName))
        urls.append(
            main.bundleURL
                .appendingPathComponent("Contents/Resources/\(fileName)")
        )
        urls.append(
            main.bundleURL
                .appendingPathComponent("Contents/Resources/\(bundleDir)/\(fileName)")
        )
        if let executableDirectory = main.executableURL?.deletingLastPathComponent() {
            urls.append(executableDirectory.appendingPathComponent(bundleDir).appendingPathComponent(fileName))
            urls.append(executableDirectory.appendingPathComponent(fileName))
        }

        urls.append(
            URL(fileURLWithPath: sourceFilePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent(fileName)
        )
        return urls
    }

    static func looksLikeCaptureScript(_ text: String) -> Bool {
        text.contains("GradleLensCollector") && text.contains("build/reports/gradlelens")
    }

    // Used only if no copy of the script is next to the binary or in the source tree.
    private static let embeddedFallback = """
        // GradleLens capture script missing from the application bundle.
        // Reinstall the app, or copy Sources/GradleLensCore/Resources/gradlelens.init.gradle.kts
        // to ~/.gradle/init.d/gradlelens.init.gradle.kts
        """
}
