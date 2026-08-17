import Foundation
import Testing

@testable import GradleLensCore

@Suite("BuildCacheInspector")
struct BuildCacheInspectorTests {
    @Test("Reports a missing cache directory")
    func missing() async {
        let inspector = BuildCacheInspector()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-missing-cache-\(UUID().uuidString)")
        let overview = await inspector.overview(at: url)
        #expect(overview.exists == false)
        #expect(overview.entryCount == 0)
    }

    @Test("Summarizes cache files")
    func summarize() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(repeating: 1, count: 100).write(to: root.appendingPathComponent("aaa111"))
        try Data(repeating: 2, count: 250).write(to: root.appendingPathComponent("bbb222"))
        try "x".write(to: root.appendingPathComponent("gc.properties"), atomically: true, encoding: .utf8)

        let overview = await BuildCacheInspector().overview(at: root, largestLimit: 2)
        #expect(overview.exists)
        #expect(overview.entryCount == 2)
        #expect(overview.totalBytes == 350)
        #expect(overview.largestEntries.first?.name == "bbb222")
        #expect(overview.largestEntries.first?.byteCount == 250)
    }
}

@Suite("IDERecentProjectsReader")
struct IDERecentProjectsReaderTests {
    @Test("Expands $USER_HOME$ and reads timestamps")
    func parseXML() throws {
        let xml = try String(contentsOf: fixtureURL("recentProjects", extension: "xml"), encoding: .utf8)
        let home = URL(fileURLWithPath: "/Users/tester")
        let items = IDERecentProjectsReader.parse(xml: xml, homeDirectory: home)
        #expect(items.count == 2)
        #expect(items.contains { $0.path == "/Users/tester/dev/OpenGibberish" })
        #expect(items.contains { $0.path == "/Users/tester/StudioProjects/Kotlin Koans" })
        let openGibberish = items.first { $0.path.hasSuffix("OpenGibberish") }
        #expect(openGibberish?.lastOpenedAt == Date(timeIntervalSince1970: 1_758_986_707.554))
    }
}

@Suite("Git log parsing")
struct GitLogParsingTests {
    @Test("Parses tab-separated git log lines")
    func parseLog() {
        let stdout = """
            abcdef0123456789\tAda\t2026-08-17T09:30:00Z\tInitial commit
            1234567890abcdef\tBen\t2026-08-16T18:00:00Z\tFix cache
            """
        let commits = GitService.parseLog(stdout)
        #expect(commits.count == 2)
        #expect(commits[0].shortSHA == "abcdef0")
        #expect(commits[0].author == "Ada")
        #expect(commits[0].subject == "Initial commit")
    }
}

@Suite("PathFormat")
struct PathFormatTests {
    @Test("Abbreviates the home directory")
    func abbreviate() {
        #expect(PathFormat.abbreviatingHome("/Users/ada/dev/app", home: "/Users/ada") == "~/dev/app")
        #expect(PathFormat.abbreviatingHome("/Users/ada", home: "/Users/ada") == "~")
        #expect(PathFormat.abbreviatingHome("/tmp/app", home: "/Users/ada") == "/tmp/app")
    }
}

@Suite("AppPaths")
struct AppPathsTests {
    @Test("Honors GRADLE_USER_HOME")
    func gradleHome() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let overridden = AppPaths.gradleUserHome(
            environment: ["GRADLE_USER_HOME": "~/custom-gradle"],
            homeDirectory: home
        )
        #expect(overridden.path.contains("custom-gradle"))

        let defaultHome = AppPaths.gradleUserHome(environment: [:], homeDirectory: home)
        #expect(defaultHome.path == "/Users/ada/.gradle")
        #expect(
            AppPaths.defaultBuildCacheDirectory(environment: [:], homeDirectory: home).path
                == "/Users/ada/.gradle/caches/build-cache-1"
        )
    }
}
