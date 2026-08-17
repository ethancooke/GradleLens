import Foundation
import Testing

@testable import GradleLensCore

@Suite("BuildIndexer")
struct BuildIndexerTests {
    @Test("Indexes profile reports under a project and skips duplicates")
    func indexReports() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-index-\(UUID().uuidString)", isDirectory: true)
        let profileDir = root.appendingPathComponent("build/reports/profile", isDirectory: true)
        try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try """
            rootProject.name = "indexed"
            include("app")
            """.write(to: root.appendingPathComponent("settings.gradle.kts"), atomically: true, encoding: .utf8)
        try """
            distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-bin.zip
            """.write(
                to: {
                    let wrapper = root.appendingPathComponent("gradle/wrapper", isDirectory: true)
                    try FileManager.default.createDirectory(at: wrapper, withIntermediateDirectories: true)
                    return wrapper.appendingPathComponent("gradle-wrapper.properties")
                }(),
                atomically: true,
                encoding: .utf8
            )

        let fixture = try String(contentsOf: fixtureURL("sample-profile", extension: "html"), encoding: .utf8)
        try fixture.write(
            to: profileDir.appendingPathComponent("profile-2026-08-17-09-30-45.html"),
            atomically: true,
            encoding: .utf8
        )

        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: root.path,
            name: "indexed",
            lastOpenedAt: .now,
            source: .manual
        )
        try await store.upsertProject(project)

        let indexer = BuildIndexer()
        let (first, structure) = try await indexer.index(project: project, store: store)
        #expect(first.imported == 1)
        #expect(first.skippedExisting == 0)
        #expect(structure.rootName == "indexed")
        #expect(structure.gradleVersion == "8.11.1")

        let (second, _) = try await indexer.index(project: project, store: store)
        #expect(second.imported == 0)
        #expect(second.skippedExisting == 1)

        let builds = try await store.builds(forProjectID: project.id)
        #expect(builds.count == 1)
        #expect(builds[0].requestedTasks == ["assemble", "test"])
        #expect(builds[0].gradleVersion == "8.11.1")
        #expect(abs(builds[0].duration - 12.345) < 0.000_1)
    }
}

@Suite("ProjectDiscoveryService")
struct ProjectDiscoveryServiceTests {
    @Test("Scans a folder for Gradle projects and skips build directories")
    func scan() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-scan-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("app", isDirectory: true)
        let nestedBuild = project.appendingPathComponent("build", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedBuild, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "rootProject.name = \"scanned\"".write(
            to: project.appendingPathComponent("settings.gradle.kts"),
            atomically: true,
            encoding: .utf8
        )
        try "rootProject.name = \"should-skip\"".write(
            to: nestedBuild.appendingPathComponent("settings.gradle.kts"),
            atomically: true,
            encoding: .utf8
        )

        let found = await ProjectDiscoveryService().scan(folder: root)
        #expect(found.map(\.name) == ["scanned"])
    }

    @Test("Rejects a folder that is not a Gradle project")
    func reject() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-not-gradle-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: GradleLensError.self) {
            try await ProjectDiscoveryService().project(at: url, source: .manual)
        }
    }
}
