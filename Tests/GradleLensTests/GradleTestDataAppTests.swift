import Foundation
import Testing

@testable import GradleLens
@testable import GradleLensCore

private enum GradleTestDataFixture {
    nonisolated static var root: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("dev/GradleTestData", isDirectory: true)
    }

    nonisolated static var isPresent: Bool {
        FileManager.default.fileExists(atPath: root.path)
    }
}

@Suite("GradleTestData through AppViewModel", .enabled(if: GradleTestDataFixture.isPresent))
@MainActor
struct GradleTestDataAppTests {
    @Test("Scan folder then select the root project and load builds")
    func scanAndSelectRoot() async throws {
        let store = try BuildHistoryStore.inMemory()
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLens-GradleTestData-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        await viewModel.scanFolder(at: GradleTestDataFixture.root)

        let names = Set(viewModel.projects.map(\.name))
        #expect(names.contains("GradleTestData"))
        #expect(names.contains("legacy-app"))
        #expect(viewModel.errorMessage == nil)

        let root = try #require(viewModel.projects.first { $0.name == "GradleTestData" })
        await viewModel.selectProject(root.id)

        #expect(viewModel.selectedProject?.name == "GradleTestData")
        #expect(viewModel.projectStructure?.gradleVersion == "9.7.0")
        #expect(viewModel.builds.count >= 6)
        #expect(viewModel.selectedDetail?.report != nil)
        #expect(viewModel.projectMissingFromDisk == false)

        viewModel.searchText = "failOnPurpose"
        #expect(!viewModel.filteredBuilds.isEmpty)
        viewModel.searchText = ""
        viewModel.outcomeFilter = .failed
        // Live Gradle 9 failOnPurpose report has an empty result cell, so it indexes as succeeded.
        #expect(viewModel.filteredBuilds.allSatisfy { $0.outcome == .failed })
    }

    @Test("Opening the Groovy sample indexes FAILED and FROM-CACHE builds")
    func openLegacySample() async throws {
        let store = try BuildHistoryStore.inMemory()
        let viewModel = AppViewModel(
            store: store,
            autoImportIDERecents: false,
            promptsForCapture: false,
            defaults: UserDefaults(suiteName: "GradleLens-GradleTestData-\(UUID().uuidString)")!
        )
        await viewModel.bootstrap()
        await viewModel.openProject(at: GradleTestDataFixture.root.appendingPathComponent("samples/legacy-app"))

        #expect(viewModel.selectedProject?.name == "legacy-app")
        #expect(viewModel.projectStructure?.gradleVersion == "8.14.3")
        #expect(viewModel.builds.count == 3)
        #expect(viewModel.builds.contains { $0.outcome == .failed })
        #expect(viewModel.selectedDetail?.report?.tasks.isEmpty == false)
    }
}
