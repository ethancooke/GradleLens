import Foundation
import Testing

@testable import GradleLensCore

private let gradleTestData = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("dev/GradleTestData", isDirectory: true)

private let fixturePresent = FileManager.default.fileExists(atPath: gradleTestData.path)

@Suite("GradleTestData fixture", .enabled(if: fixturePresent))
struct GradleTestDataIntegrationTests {
    @Test("Scan finds the root, included builds, and sample projects")
    func scan() async {
        let found = await ProjectDiscoveryService().scan(folder: gradleTestData)
        let names = Set(found.map(\.name))
        let paths = Set(found.map { PathFormat.abbreviatingHome($0.rootPath) })

        #expect(names.contains("GradleTestData"))
        #expect(names.contains("legacy-app"))
        #expect(names.contains("orphan-settings"))
        #expect(found.contains { $0.rootPath.hasSuffix("/samples/single-module") })
        #expect(found.contains { $0.rootPath.hasSuffix("/build-logic") })
        #expect(found.contains { $0.rootPath.hasSuffix("/buildSrc") })
        #expect(found.contains { $0.rootPath.hasSuffix("/convention-plugins") })
        #expect(found.count >= 7, "paths: \(paths.sorted())")
    }

    @Test("Root structure, wrapper, and nested modules parse")
    func rootStructure() throws {
        let structure = try ProjectStructureReader().read(projectRoot: gradleTestData)
        #expect(structure.rootName == "GradleTestData")
        #expect(structure.gradleVersion == "9.7.0")
        #expect(structure.settingsFileName == "settings.gradle.kts")
        #expect(structure.includedBuilds.contains("build-logic"))
        #expect(structure.includedBuilds.contains("convention-plugins"))

        let modulePaths = Set(structure.modules.map(\.path))
        #expect(modulePaths.contains(":app"))
        #expect(modulePaths.contains(":list"))
        #expect(modulePaths.contains(":utilities"))
        #expect(modulePaths.contains(":feature:home"))
        #expect(modulePaths.contains(":legacy"))
        #expect(structure.modules.contains { $0.directory == "feature/home" })
    }

    @Test("Indexes every root --profile report")
    func indexRootProfiles() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = try await ProjectDiscoveryService().project(at: gradleTestData, source: .manual)
        try await store.upsertProject(project)

        let indexer = BuildIndexer()
        let (result, _) = try await indexer.index(project: project, store: store)
        #expect(result.failed == 0)
        #expect(result.imported >= 6)

        let builds = try await store.builds(forProjectID: project.id)
        #expect(builds.count >= 6)

        let requested = Set(builds.map(\.requestedTasksLabel))
        #expect(requested.contains { $0.contains("failOnPurpose") })
        #expect(requested.contains { $0.contains(":app:run") })
        #expect(requested.contains { $0.contains("clean") })
        #expect(builds.allSatisfy { $0.gradleVersion == "9.7.0" })
        #expect(builds.allSatisfy { ($0.duration) >= 0 })

        let (second, _) = try await indexer.index(project: project, store: store)
        #expect(second.imported == 0)
        #expect(second.skippedExisting == result.imported)
    }

    @Test("Parses live Gradle 9 profile HTML including FROM-CACHE rows")
    func parseLiveProfiles() throws {
        let parser = ProfileReportParser()
        let profileDir = gradleTestData.appendingPathComponent("build/reports/profile")
        let files = try FileManager.default.contentsOfDirectory(
            at: profileDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "html" && $0.lastPathComponent.hasPrefix("profile-") }

        #expect(files.count >= 6)

        var parsed: [ProfileReport] = []
        for file in files {
            parsed.append(try parser.parse(fileAt: file))
        }

        let cacheHit = try #require(parsed.first { $0.requestedTasks == ["clean", "build"] })
        #expect(cacheHit.summary.totalBuildTime > 0)
        #expect(cacheHit.tasks.contains { $0.result == .fromCache })
        #expect(cacheHit.tasks.contains { $0.result == .upToDate || $0.result == .executed })

        let failedTask = try #require(parsed.first { $0.requestedTasks == ["failOnPurpose"] })
        #expect(failedTask.tasks.contains { $0.path == ":failOnPurpose" })
        // Gradle 9 left the result cell empty for this failing task, so outcome is succeeded.
        #expect(failedTask.outcome == .succeeded)
        #expect(failedTask.tasks.first { $0.path == ":failOnPurpose" }?.result == .executed)
    }

    @Test("Parses hand-authored sample reports with FAILED and FROM-CACHE")
    func parseSampleReports() throws {
        let parser = ProfileReportParser()
        let failed = try parser.parse(
            fileAt: gradleTestData.appendingPathComponent(
                "samples/legacy-app/build/reports/profile/profile-2026-08-08-09-41-03.html"
            )
        )
        #expect(failed.requestedTasks == ["test"])
        #expect(failed.outcome == .failed)
        #expect(failed.tasks.contains { $0.path == ":app:test" && $0.result == .failed })

        let cached = try parser.parse(
            fileAt: gradleTestData.appendingPathComponent(
                "samples/legacy-app/build/reports/profile/profile-2026-08-04-16-02-11.html"
            )
        )
        #expect(cached.tasks.contains { $0.result == .fromCache })

        let orphan = try parser.parse(
            fileAt: gradleTestData.appendingPathComponent(
                "samples/no-wrapper/build/reports/profile/profile-2026-08-12-08-00-00.html"
            )
        )
        #expect(orphan.requestedTasks == ["ping"])
        #expect(orphan.summary.totalBuildTime > 0)
    }

    @Test("Single-module sample is detected without settings or wrapper")
    func singleModule() throws {
        let url = gradleTestData.appendingPathComponent("samples/single-module")
        #expect(GradleProjectDetector.isGradleProject(at: url))
        #expect(GradleProjectDetector.settingsFile(at: url) == nil)
        #expect(GradleProjectDetector.gradleVersion(at: url) == nil)
        let structure = try ProjectStructureReader().read(projectRoot: url)
        #expect(structure.modules.count == 1)
        #expect(structure.gradleVersion == nil)
    }

    @Test("Git context is readable when the fixture is a repo")
    func git() async {
        let context = await GitService().context(for: gradleTestData)
        if FileManager.default.fileExists(atPath: gradleTestData.appendingPathComponent(".git").path) {
            #expect(context.isRepository)
            #expect(context.branch != nil)
        } else {
            #expect(context.isRepository == false)
        }
    }

    @Test("Local build cache inspector returns stats for this machine")
    func cache() async {
        let overview = await BuildCacheInspector().overview()
        if overview.exists {
            #expect(overview.entryCount > 0)
            #expect(overview.totalBytes > 0)
        }
    }
}
