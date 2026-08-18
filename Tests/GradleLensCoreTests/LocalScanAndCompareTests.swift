import Foundation
import Testing

@testable import GradleLensCore

@Suite("LocalScanParser")
struct LocalScanParserTests {
    @Test("Parses a GradleLens scan JSON file")
    func parseFixture() throws {
        let url = try fixtureURL("sample-scan", extension: "json")
        let scan = try LocalScanParser().parse(fileAt: url)
        #expect(scan.schemaVersion == 1)
        #expect(scan.outcome == .failed)
        #expect(scan.requestedTasks == ["assemble", "test"])
        #expect(scan.excludedTasks == ["lint"])
        #expect(scan.gradleVersion == "9.7.0")
        #expect(scan.configurationCacheRequested == true)
        #expect(scan.git?.branch == "main")
        #expect(scan.git?.dirty == true)
        #expect(scan.tasks.count == 3)
        #expect(scan.tasks.last?.result == .failed)
        #expect(scan.tasks.first?.startOffset == 2.0)
        #expect(abs(scan.duration - 12.345) < 0.000_1)
    }

    @Test("Rejects invalid JSON")
    func invalid() {
        #expect(throws: GradleLensError.self) {
            try LocalScanParser().parse(data: Data("{}".utf8), sourcePath: "/tmp/x.json")
        }
    }
}

@Suite("CaptureMerge")
struct CaptureMergeTests {
    @Test("Prefers scan outcome and task start offsets over HTML")
    func merge() throws {
        let profile = try ProfileReportParser().parse(fileAt: fixtureURL("sample-profile", extension: "html"))
        let scan = try LocalScanParser().parse(fileAt: fixtureURL("sample-scan", extension: "json"))
        let merged = try #require(CaptureMerge.report(profile: profile, scan: scan))
        #expect(merged.outcome == .failed)
        #expect(merged.declaredOutcome == .failed)
        #expect(merged.hasStartOffsets)
        #expect(merged.summary.startup == profile.summary.startup)
        #expect(merged.tasks.contains { $0.path == ":app:test" && $0.result == .failed })
    }
}

@Suite("BuildComparator")
struct BuildComparatorTests {
    @Test("Computes duration, appearance, and cache flips")
    func compare() {
        let baselineRecord = BuildRecord(
            projectID: "/tmp/p",
            startedAt: Date(timeIntervalSince1970: 1),
            duration: 10,
            outcome: .succeeded,
            requestedTasks: ["assemble"]
        )
        let candidateRecord = BuildRecord(
            projectID: "/tmp/p",
            startedAt: Date(timeIntervalSince1970: 2),
            duration: 14,
            outcome: .failed,
            requestedTasks: ["assemble"]
        )
        let baseline = BuildDetail(
            record: baselineRecord,
            report: report(
                duration: 10,
                tasks: [
                    ProfileTask(path: ":a", duration: 4, result: .executed),
                    ProfileTask(path: ":b", duration: 3, result: .fromCache),
                    ProfileTask(path: ":gone", duration: 1, result: .executed),
                ]
            )
        )
        let candidate = BuildDetail(
            record: candidateRecord,
            report: report(
                duration: 14,
                tasks: [
                    ProfileTask(path: ":a", duration: 8, result: .executed),
                    ProfileTask(path: ":b", duration: 3, result: .executed),
                    ProfileTask(path: ":new", duration: 2, result: .executed),
                ]
            )
        )
        let comparison = BuildComparator().compare(baseline: baseline, candidate: candidate)
        #expect(abs(comparison.durationDelta - 4) < 0.000_1)
        #expect(comparison.appeared.map(\.path) == [":new"])
        #expect(comparison.disappeared.map(\.path) == [":gone"])
        #expect(comparison.sharedTaskDeltas.first?.path == ":a")
        #expect(comparison.cacheFlips.contains { $0.path == ":b" })
    }

    private func report(duration: TimeInterval, tasks: [ProfileTask]) -> ProfileReport {
        ProfileReport(
            sourcePath: "/tmp/p.html",
            startedAt: .now,
            requestedTasks: ["assemble"],
            summary: ProfileSummary(
                totalBuildTime: duration,
                startup: 1,
                settingsAndBuildSrc: 1,
                loadingProjects: 0,
                configuringProjects: 1,
                artifactTransforms: 0,
                taskExecution: duration - 3
            ),
            configuration: [],
            dependencyResolution: [],
            artifactTransforms: [],
            projectTotals: [],
            tasks: tasks
        )
    }
}

@Suite("CaptureScriptInstaller")
struct CaptureScriptInstallerTests {
    @Test("Bundled script is a real init script")
    func bundled() {
        let script = CaptureScriptInstaller.bundledScript()
        #expect(script.contains("GradleLensCollector"))
        #expect(script.contains("build/reports/gradlelens"))
        #expect(script.contains("schemaVersion"))
    }

    @Test("Installs into a fake Gradle user home")
    func install() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let installer = CaptureScriptInstaller(homeDirectory: home)
        let env = ["GRADLE_USER_HOME": home.appendingPathComponent(".gradle").path]
        #expect(installer.status(environment: env).installed == false)
        try installer.install(environment: env)
        let status = installer.status(environment: env)
        #expect(status.installed)
        #expect(status.matchesBundled)
        #expect(FileManager.default.fileExists(atPath: status.path))
    }
}

@Suite("BuildIndexer scan pairing")
struct BuildIndexerScanTests {
    @Test("Pairs a scan with a nearby profile and records failure + git")
    func pairScanAndProfile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-scan-\(UUID().uuidString)", isDirectory: true)
        let profileDir = root.appendingPathComponent("build/reports/profile", isDirectory: true)
        let scanDir = root.appendingPathComponent("build/reports/gradlelens", isDirectory: true)
        try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "rootProject.name = \"scanned\"".write(
            to: root.appendingPathComponent("settings.gradle.kts"),
            atomically: true,
            encoding: .utf8
        )
        let scanJSON = try String(contentsOf: fixtureURL("sample-scan", extension: "json"), encoding: .utf8)
        try scanJSON.write(
            to: scanDir.appendingPathComponent("scan-2026-08-17-09-30-45.json"),
            atomically: true,
            encoding: .utf8
        )
        let scan = try LocalScanParser().parse(
            fileAt: scanDir.appendingPathComponent("scan-2026-08-17-09-30-45.json")
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy/MM/dd - HH:mm:ss"
        let started = formatter.string(from: scan.startedAt)
        let profileHTML = """
            <div id="header"><p>Profiled build: assemble test </p><p>Started on: \(started)</p></div>
            <h2>Summary</h2>
            <table>
            <tr><td>Total Build Time</td><td>12.345s</td></tr>
            <tr><td>Startup</td><td>0.234s</td></tr>
            <tr><td>Settings and buildSrc</td><td>0.456s</td></tr>
            <tr><td>Loading Projects</td><td>0.012s</td></tr>
            <tr><td>Configuring Projects</td><td>1.234s</td></tr>
            <tr><td>Artifact Transforms</td><td>0.100s</td></tr>
            <tr><td>Task Execution</td><td>10.000s</td></tr>
            </table>
            <h2>Task Execution</h2>
            <table>
            <tr><td>:app:compileKotlin</td><td>4.500s</td><td></td></tr>
            </table>
            """
        try profileHTML.write(
            to: profileDir.appendingPathComponent("profile-2026-08-17-09-30-45.html"),
            atomically: true,
            encoding: .utf8
        )

        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(rootPath: root.path, name: "scanned", lastOpenedAt: .now, source: .manual)
        try await store.upsertProject(project)
        let (result, _) = try await BuildIndexer().index(project: project, store: store)
        #expect(result.imported == 1)
        #expect(result.failed == 0)

        let builds = try await store.builds(forProjectID: project.id)
        #expect(builds.count == 1)
        #expect(builds[0].outcome == .failed)
        #expect(builds[0].hasLocalScan)
        #expect(builds[0].profilePath != nil)
        #expect(builds[0].gitBranch == "main")

        let detail = await BuildIndexer().loadDetail(for: builds[0])
        #expect(detail.scan?.outcome == .failed)
        #expect(detail.report?.outcome == .failed)
        #expect(detail.report?.hasStartOffsets == true)
    }
}
