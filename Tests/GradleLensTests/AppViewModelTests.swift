import Foundation
import Testing

@testable import GradleLens
@testable import GradleLensCore

@Suite("AppViewModel")
@MainActor
struct AppViewModelTests {
    @Test("Bootstraps an empty store without importing IDE recents")
    func emptyBootstrap() async throws {
        let store = try BuildHistoryStore.inMemory()
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        #expect(viewModel.projects.isEmpty)
        #expect(viewModel.selectedProjectID == nil)
    }

    @Test("Opens a Gradle project and indexes its profile report")
    func openAndIndex() async throws {
        let root = try makeTempProject(named: "vm-demo", withProfile: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try BuildHistoryStore.inMemory()
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        await viewModel.openProject(at: root)

        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects.first?.name == "vm-demo")
        #expect(viewModel.selectedProjectID == root.path)
        #expect(viewModel.builds.count == 1)
        #expect(viewModel.selectedDetail?.report?.tasks.isEmpty == false)
        #expect(viewModel.projectStructure?.rootName == "vm-demo")
    }

    @Test("Filters builds by search text and outcome")
    func filterBuilds() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/filter-demo",
            name: "filter-demo",
            lastOpenedAt: .now,
            source: .manual
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

        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        await viewModel.selectProject(project.id)

        #expect(viewModel.filteredBuilds.count == 2)
        viewModel.searchText = "assemble"
        #expect(viewModel.filteredBuilds.map(\.requestedTasks) == [["assemble"]])
        viewModel.searchText = ""
        viewModel.outcomeFilter = .failed
        #expect(viewModel.filteredBuilds.map(\.outcome) == [.failed])
    }

    @Test("Removes a project from the local index only")
    func removeProject() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/remove-demo",
            name: "remove-demo",
            lastOpenedAt: .now,
            source: .manual
        )
        try await store.upsertProject(project)
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        #expect(viewModel.projects.count == 1)
        await viewModel.removeProject(project.id)
        #expect(viewModel.projects.isEmpty)
    }

    @Test("Compares the selected build with the previous one")
    func compareWithPrevious() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/compare-demo",
            name: "compare-demo",
            lastOpenedAt: .now,
            source: .manual
        )
        try await store.upsertProject(project)
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: Date(timeIntervalSince1970: 1),
                duration: 10,
                outcome: .succeeded,
                requestedTasks: ["assemble"]
            )
        )
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: Date(timeIntervalSince1970: 2),
                duration: 14,
                outcome: .succeeded,
                requestedTasks: ["assemble"]
            )
        )
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        await viewModel.selectProject(project.id)
        #expect(viewModel.filteredBuilds.count == 2)
        await viewModel.compareWithPrevious()
        #expect(viewModel.comparison != nil)
        #expect(abs((viewModel.comparison?.durationDelta ?? 0) - 4) < 0.000_1)
        viewModel.clearComparison()
        #expect(viewModel.comparison == nil)
    }

    @Test("Trends group commands and honor a custom range")
    func trends() async throws {
        let store = try BuildHistoryStore.inMemory()
        let project = GradleProject(
            rootPath: "/tmp/trend-demo",
            name: "trend-demo",
            lastOpenedAt: .now,
            source: .manual
        )
        try await store.upsertProject(project)
        let now = Date()
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: now.addingTimeInterval(-86_400 * 40),
                duration: 50,
                outcome: .succeeded,
                requestedTasks: ["assemble"]
            )
        )
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: now.addingTimeInterval(-3_600),
                duration: 12,
                outcome: .succeeded,
                requestedTasks: ["assemble"]
            )
        )
        try await store.upsertBuild(
            BuildRecord(
                projectID: project.id,
                startedAt: now.addingTimeInterval(-1_800),
                duration: 9,
                outcome: .failed,
                requestedTasks: ["test"]
            )
        )
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        await viewModel.selectProject(project.id)
        viewModel.showTrends(for: "assemble")
        #expect(viewModel.showingTrends)
        #expect(viewModel.commandSeries.count == 2)
        viewModel.trendRange.preset = .month
        #expect(viewModel.trendSnapshot?.runs.count == 1)
        viewModel.trendRange.preset = .all
        #expect(viewModel.trendSnapshot?.runs.count == 2)
        #expect(viewModel.trendSnapshot?.stats.medianDuration == 31)
    }

    @Test("First launch can prompt for capture; tests can skip the prompt")
    func capturePrompt() async throws {
        let store = try BuildHistoryStore.inMemory()
        let defaults = UserDefaults(suiteName: "GradleLensTests-\(UUID().uuidString)")!
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("GradleLens-onboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let installer = CaptureScriptInstaller(
            homeDirectory: home,
            environment: ["GRADLE_USER_HOME": home.appendingPathComponent(".gradle").path]
        )
        let viewModel = AppViewModel(
            store: store,
            captureInstaller: installer,
            autoImportIDERecents: false,
            promptsForCapture: true,
            defaults: defaults
        )
        await viewModel.bootstrap()
        #expect(viewModel.showCaptureOnboarding == true)
        viewModel.dismissCaptureOnboarding()
        #expect(viewModel.showCaptureOnboarding == false)

        let again = AppViewModel(
            store: store,
            captureInstaller: installer,
            autoImportIDERecents: false,
            promptsForCapture: true,
            defaults: defaults
        )
        await again.bootstrap()
        #expect(again.showCaptureOnboarding == false)
    }
}

@Suite("LaunchArguments")
struct LaunchArgumentsTests {
    @Test("Parses --open and expands a tilde")
    func parseOpen() {
        let url = LaunchArguments.openFolder(from: ["GradleLens", "--open", "~/dev/GradleTestData"])
        #expect(url?.path.hasSuffix("/dev/GradleTestData") == true)
        #expect(LaunchArguments.openFolder(from: ["GradleLens"]) == nil)
    }
}

private func makeTempProject(named name: String, withProfile: Bool) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("GradleLens-vm-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "rootProject.name = \"\(name)\"".write(
        to: root.appendingPathComponent("settings.gradle.kts"),
        atomically: true,
        encoding: .utf8
    )
    if withProfile {
        let profileDir = root.appendingPathComponent("build/reports/profile", isDirectory: true)
        try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
        let html = """
            <h2>Summary</h2>
            <table>
            <tr><td>Total Build Time</td><td>2.500s</td></tr>
            <tr><td>Startup</td><td>0.100s</td></tr>
            <tr><td>Settings and buildSrc</td><td>0.100s</td></tr>
            <tr><td>Loading Projects</td><td>0s</td></tr>
            <tr><td>Configuring Projects</td><td>0.300s</td></tr>
            <tr><td>Artifact Transforms</td><td>0s</td></tr>
            <tr><td>Task Execution</td><td>2.000s</td></tr>
            </table>
            <div id="header"><p>Profiled build: assemble </p><p>Started on: 2026/08/17 - 10:00:00</p></div>
            <h2>Task Execution</h2>
            <table>
            <tr><td>:app:compileKotlin</td><td>2.000s</td><td></td></tr>
            </table>
            """
        try html.write(
            to: profileDir.appendingPathComponent("profile-2026-08-17-10-00-00.html"),
            atomically: true,
            encoding: .utf8
        )
    }
    return root
}
