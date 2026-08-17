import Foundation

public enum GradleProjectDetector: Sendable {
    public static let settingsFileNames = ["settings.gradle.kts", "settings.gradle"]
    public static let buildFileNames = ["build.gradle.kts", "build.gradle"]

    public static func isGradleProject(at url: URL) -> Bool {
        let values = (try? url.resourceValues(forKeys: [.isDirectoryKey])) 
        if values?.isDirectory == false { return false }
        return settingsFile(at: url) != nil || buildFile(at: url) != nil
    }

    public static func settingsFile(at url: URL) -> URL? {
        firstExisting(named: settingsFileNames, under: url)
    }

    public static func buildFile(at url: URL) -> URL? {
        firstExisting(named: buildFileNames, under: url)
    }

    public static func displayName(at url: URL, fallbackToDirectory: Bool = true) -> String {
        if let settings = settingsFile(at: url),
           let contents = try? String(contentsOf: settings, encoding: .utf8),
           let name = ProjectStructureReader.rootProjectName(in: contents)
        {
            return name
        }
        if fallbackToDirectory {
            return url.lastPathComponent
        }
        return url.lastPathComponent
    }

    public static func wrapperProperties(at url: URL) -> URL {
        url.appendingPathComponent("gradle", isDirectory: true)
            .appendingPathComponent("wrapper", isDirectory: true)
            .appendingPathComponent("gradle-wrapper.properties")
    }

    public static func gradleVersion(at projectRoot: URL) -> String? {
        let propertiesURL = wrapperProperties(at: projectRoot)
        guard let contents = try? String(contentsOf: propertiesURL, encoding: .utf8) else { return nil }
        return gradleVersion(fromWrapperProperties: contents)
    }

    public static func gradleVersion(fromWrapperProperties contents: String) -> String? {
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("distributionUrl") else { continue }
            guard let equals = trimmed.firstIndex(of: "=") else { continue }
            let value = trimmed[trimmed.index(after: equals)...]
            if let match = value.range(of: #"gradle-.+?-(?:bin|all)(?:\.zip)?"#, options: .regularExpression) {
                var token = String(value[match])
                if token.hasPrefix("gradle-") {
                    token.removeFirst("gradle-".count)
                }
                if token.hasSuffix(".zip") {
                    token.removeLast(4)
                }
                if token.hasSuffix("-bin") || token.hasSuffix("-all") {
                    token.removeLast(4)
                }
                return token
            }
        }
        return nil
    }

    private static func firstExisting(named names: [String], under root: URL) -> URL? {
        for name in names {
            let candidate = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
