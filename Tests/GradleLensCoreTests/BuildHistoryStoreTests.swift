import Foundation
import Testing

@testable import GradleLensCore

@Suite("BuildHistoryStore")
struct BuildHistoryStoreTests {
    @Test("Persists projects and builds")
    func persist() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/demo",
            name: "demo",
            lastOpenedAt: Date(timeIntervalSince1970: 100),
            source: .manual
        )
        try await store.upsertProject(project)

        let build = BuildRecord(
            projectID: project.id,
            startedAt: Date(timeIntervalSince1970: 200),
            duration: 12.3,
            outcome: .succeeded,
            requestedTasks: ["assemble"],
            gradleVersion: "8.14.3",
            profilePath: "/tmp/demo/build/reports/profile/profile-1.html"
        )
        try await store.upsertBuild(build)

        let projects = try await store.allProjects()
        #expect(projects.map(\.name) == ["demo"])
        #expect(try await store.containsProfile(path: build.profilePath!))

        let loaded = try await store.builds(forProjectID: project.id)
        #expect(loaded.count == 1)
        #expect(loaded[0].requestedTasks == ["assemble"])
        #expect(loaded[0].duration == 12.3)
        #expect(loaded[0].gradleVersion == "8.14.3")
    }

    @Test("Upserts a build by profile path")
    func upsertByProfile() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/demo2",
            name: "demo2",
            lastOpenedAt: .now,
            source: .manual
        )
        try await store.upsertProject(project)
        let path = "/tmp/demo2/profile.html"
        let first = BuildRecord(
            projectID: project.id,
            startedAt: Date(timeIntervalSince1970: 1),
            duration: 1,
            outcome: .succeeded,
            requestedTasks: ["help"],
            profilePath: path
        )
        let second = BuildRecord(
            projectID: project.id,
            startedAt: Date(timeIntervalSince1970: 2),
            duration: 9,
            outcome: .failed,
            requestedTasks: ["test"],
            profilePath: path
        )
        try await store.upsertBuild(first)
        try await store.upsertBuild(second)
        let loaded = try await store.builds(forProjectID: project.id)
        #expect(loaded.count == 1)
        #expect(loaded[0].outcome == .failed)
        #expect(loaded[0].duration == 9)
        #expect(loaded[0].requestedTasks == ["test"])
    }

    @Test("Filters builds by search and outcome")
    func query() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/demo3",
            name: "demo3",
            lastOpenedAt: .now,
            source: .folderScan
        )
        try await store.upsertProject(project)
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: Date(timeIntervalSince1970: 1),
                duration: 1,
                outcome: .succeeded,
                requestedTasks: ["assemble"]
            )
        )
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: Date(timeIntervalSince1970: 2),
                duration: 2,
                outcome: .failed,
                requestedTasks: ["test"]
            )
        )

        let failed = try await store.builds(
            forProjectID: project.id,
            matching: BuildQuery(outcome: .failed)
        )
        #expect(failed.map(\.requestedTasks) == [["test"]])

        let searched = try await store.builds(
            forProjectID: project.id,
            matching: BuildQuery(search: "assemble")
        )
        #expect(searched.count == 1)
        #expect(searched[0].requestedTasks == ["assemble"])
    }

    @Test("Removing a project cascades to its builds")
    func cascade() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/demo4",
            name: "demo4",
            lastOpenedAt: .now,
            source: .ideRecents
        )
        try await store.upsertProject(project)
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: .now,
                duration: 1,
                outcome: .unknown,
                requestedTasks: []
            )
        )
        try await store.removeProject(id: project.id)
        #expect(try await store.allProjects().isEmpty)
        #expect(try await store.builds(forProjectID: project.id).isEmpty)
    }
}
