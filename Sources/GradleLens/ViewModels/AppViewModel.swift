import Foundation
import GradleLensCore

@MainActor
@Observable
final class AppViewModel {
    private static let lastProjectKey = "GradleLens.lastProjectPath"
    private static let capturePromptedKey = "GradleLens.capturePrompted"

    var projects: [GradleProject] = []
    var selectedProjectID: String?
    var builds: [BuildRecord] = []
    var selectedBuildID: UUID?
    var selectedDetail: BuildDetail?
    var cacheOverview: BuildCacheOverview?
    var gitContext: GitContext?
    var projectStructure: ProjectStructure?
    var searchText = ""
    var outcomeFilter: BuildOutcome?
    var taskSearch = ""
    var isLoading = false
    var isIndexing = false
    var statusMessage: String?
    var errorMessage: String?
    var inspectorVisible = true
    var projectMissingFromDisk = false
    var compareBaselineID: UUID?
    var compareCandidateID: UUID?
    var comparison: BuildComparison?
    var captureStatus: CaptureInstallStatus?
    var confirmInstallCapture = false
    var showCaptureOnboarding = false
    var showingTrends = false
    var selectedCommandKey: String?
    var trendRange = TrendRange()
    var trendBranch: String?

    private var store: BuildHistoryStore?
    private let discovery: ProjectDiscoveryService
    private let indexer: BuildIndexer
    private let cacheInspector: BuildCacheInspector
    private let git: GitService
    private let structureReader: ProjectStructureReader
    private let comparator: BuildComparator
    private let captureInstaller: CaptureScriptInstaller
    private let autoImportIDERecents: Bool
    private let promptsForCapture: Bool
    private let defaults: UserDefaults

    init(
        store: BuildHistoryStore? = nil,
        discovery: ProjectDiscoveryService = ProjectDiscoveryService(),
        indexer: BuildIndexer = BuildIndexer(),
        cacheInspector: BuildCacheInspector = BuildCacheInspector(),
        git: GitService = GitService(),
        structureReader: ProjectStructureReader = ProjectStructureReader(),
        comparator: BuildComparator = BuildComparator(),
        captureInstaller: CaptureScriptInstaller = CaptureScriptInstaller(),
        autoImportIDERecents: Bool = true,
        promptsForCapture: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.discovery = discovery
        self.indexer = indexer
        self.cacheInspector = cacheInspector
        self.git = git
        self.structureReader = structureReader
        self.comparator = comparator
        self.captureInstaller = captureInstaller
        self.autoImportIDERecents = autoImportIDERecents
        self.promptsForCapture = promptsForCapture
        self.defaults = defaults
    }

    var selectedProject: GradleProject? {
        projects.first { $0.id == selectedProjectID }
    }

    var selectedBuild: BuildRecord? {
        builds.first { $0.id == selectedBuildID }
    }

    var filteredBuilds: [BuildRecord] {
        builds.filter { record in
            if let outcomeFilter, record.outcome != outcomeFilter { return false }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }
            return record.requestedTasksLabel.localizedCaseInsensitiveContains(query)
                || record.outcome.displayName.localizedCaseInsensitiveContains(query)
                || (record.gradleVersion?.localizedCaseInsensitiveContains(query) ?? false)
                || (record.profilePath?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if store == nil {
                store = try BuildHistoryStore.applicationDefault()
            }
            async let cache = cacheInspector.overview()
            var loaded = try await requireStore().allProjects()
            if loaded.isEmpty && autoImportIDERecents {
                let recents = await discovery.importIDERecents()
                for project in recents {
                    try await requireStore().upsertProject(project)
                }
                loaded = try await requireStore().allProjects()
                if !recents.isEmpty {
                    statusMessage = "Imported \(recents.count) Gradle project\(recents.count == 1 ? "" : "s") from Android Studio / IntelliJ recents."
                }
            }
            projects = loaded
            cacheOverview = await cache
            refreshCaptureStatus()

            if let last = defaults.string(forKey: Self.lastProjectKey),
               projects.contains(where: { $0.id == last })
            {
                await selectProject(last)
            } else if let first = projects.first {
                await selectProject(first.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        considerCaptureOnboarding()
    }

    func openProject(at url: URL) async {
        do {
            let project = try await discovery.project(at: url, source: .manual)
            try await requireStore().upsertProject(project)
            try await reloadProjects()
            await selectProject(project.id)
            statusMessage = "Opened \(project.name)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scanFolder(at url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let found = await discovery.scan(folder: url)
            for project in found {
                if let existing = try await requireStore().project(id: project.id) {
                    try await requireStore().upsertProject(
                        GradleProject(
                            rootPath: existing.rootPath,
                            name: project.name,
                            lastOpenedAt: existing.lastOpenedAt,
                            lastIndexedAt: existing.lastIndexedAt,
                            source: existing.source
                        )
                    )
                } else {
                    try await requireStore().upsertProject(project)
                }
            }
            try await reloadProjects()
            if let first = found.first, selectedProjectID == nil {
                await selectProject(first.id)
            }
            statusMessage = found.isEmpty
                ? "No Gradle projects found in that folder."
                : "Found \(found.count) Gradle project\(found.count == 1 ? "" : "s")."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectProject(_ id: String?) async {
        selectedProjectID = id
        selectedBuildID = nil
        selectedDetail = nil
        builds = []
        gitContext = nil
        projectStructure = nil
        projectMissingFromDisk = false
        taskSearch = ""
        selectedCommandKey = nil
        trendBranch = nil
        showingTrends = false
        clearComparison()

        guard let id else { return }
        defaults.set(id, forKey: Self.lastProjectKey)

        do {
            guard var project = try await requireStore().project(id: id) else { return }
            projectMissingFromDisk = !FileManager.default.fileExists(atPath: project.rootPath)
            project = project.touchingOpened()
            try await requireStore().upsertProject(project)
            try await reloadProjects()

            if !projectMissingFromDisk {
                projectStructure = try? structureReader.read(projectRoot: project.rootURL)
                async let gitLoad = git.context(for: project.rootURL)
                await indexSelectedProject()
                gitContext = await gitLoad
            }

            builds = try await requireStore().builds(forProjectID: id)
            if let first = filteredBuilds.first {
                await selectBuild(first.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectBuild(_ id: UUID?) async {
        selectedBuildID = id
        taskSearch = ""
        guard let id, let record = builds.first(where: { $0.id == id }) else {
            selectedDetail = nil
            return
        }
        selectedDetail = await indexer.loadDetail(for: record)
        selectedCommandKey = record.commandKey
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            cacheOverview = await cacheInspector.overview()
            if let id = selectedProjectID {
                await selectProject(id)
            } else {
                try await reloadProjects()
            }
            statusMessage = "Refreshed"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshCache() async {
        cacheOverview = await cacheInspector.overview()
    }

    func importIDERecents() async {
        do {
            let recents = await discovery.importIDERecents()
            for project in recents {
                if try await requireStore().project(id: project.id) == nil {
                    try await requireStore().upsertProject(project)
                }
            }
            try await reloadProjects()
            statusMessage = recents.isEmpty
                ? "No Gradle projects found in IDE recents."
                : "Imported IDE recents (\(recents.count))."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeProject(_ id: String) async {
        do {
            try await requireStore().removeProject(id: id)
            if selectedProjectID == id {
                selectedProjectID = nil
                selectedBuildID = nil
                selectedDetail = nil
                builds = []
                gitContext = nil
                projectStructure = nil
            }
            try await reloadProjects()
            if selectedProjectID == nil, let first = projects.first {
                await selectProject(first.id)
            }
            statusMessage = "Removed from GradleLens (files were not deleted)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    var commandSeries: [CommandSeries] {
        TrendAnalyzer().commands(in: builds)
    }

    var selectedCommandOrDefault: String? {
        if let selectedCommandKey { return selectedCommandKey }
        if let selected = selectedBuild { return selected.commandKey }
        return commandSeries.first?.key
    }

    var trendSnapshot: TrendSnapshot? {
        guard let key = selectedCommandOrDefault else { return nil }
        return TrendAnalyzer().snapshot(
            in: builds,
            commandKey: key,
            range: trendRange,
            branch: trendBranch
        )
    }

    func showTrends(for commandKey: String? = nil) {
        showingTrends = true
        comparison = nil
        if let commandKey {
            selectedCommandKey = commandKey
        } else if selectedCommandKey == nil {
            selectedCommandKey = selectedCommandOrDefault
        }
    }

    func selectCommand(_ key: String?) {
        selectedCommandKey = key
    }

    var isComparing: Bool {
        compareBaselineID != nil && compareCandidateID != nil && comparison != nil
    }

    func markForCompare(_ id: UUID) async {
        if compareBaselineID == nil {
            compareBaselineID = id
            statusMessage = "Baseline set. Choose another build to compare."
            return
        }
        if compareBaselineID == id {
            return
        }
        compareCandidateID = id
        await refreshComparison()
    }

    func compareWithPrevious() async {
        guard let current = selectedBuildID,
              let index = filteredBuilds.firstIndex(where: { $0.id == current }),
              filteredBuilds.indices.contains(index + 1)
        else {
            statusMessage = "Need an older build in this list to compare."
            return
        }
        compareBaselineID = filteredBuilds[index + 1].id
        compareCandidateID = current
        await refreshComparison()
    }

    func swapComparison() async {
        swap(&compareBaselineID, &compareCandidateID)
        await refreshComparison()
    }

    func clearComparison() {
        compareBaselineID = nil
        compareCandidateID = nil
        comparison = nil
    }

    var isRicherCaptureEnabled: Bool {
        captureStatus?.installed == true
    }

    func requestInstallCapture() {
        confirmInstallCapture = true
    }

    func installCaptureScript() {
        setRicherCaptureEnabled(true)
    }

    func setRicherCaptureEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try captureInstaller.install()
            } else {
                try captureInstaller.uninstall()
            }
            refreshCaptureStatus()
            defaults.set(true, forKey: Self.capturePromptedKey)
            showCaptureOnboarding = false
            confirmInstallCapture = false
            statusMessage = enabled
                ? "Richer capture is on. Future Gradle builds on this Mac will write extra local reports."
                : "Richer capture is off. The helper was removed from ~/.gradle/init.d."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissCaptureOnboarding() {
        defaults.set(true, forKey: Self.capturePromptedKey)
        showCaptureOnboarding = false
    }

    func refreshCaptureStatus() {
        captureStatus = captureInstaller.status()
    }

    private func considerCaptureOnboarding() {
        guard promptsForCapture else { return }
        if captureStatus?.installed == true {
            defaults.set(true, forKey: Self.capturePromptedKey)
            return
        }
        if !defaults.bool(forKey: Self.capturePromptedKey) {
            showCaptureOnboarding = true
        }
    }

    private func refreshComparison() async {
        guard let baseID = compareBaselineID, let candID = compareCandidateID else {
            comparison = nil
            return
        }
        guard let baseRecord = builds.first(where: { $0.id == baseID }),
              let candRecord = builds.first(where: { $0.id == candID })
        else {
            comparison = nil
            return
        }
        let baseline = await indexer.loadDetail(for: baseRecord)
        let candidate = await indexer.loadDetail(for: candRecord)
        comparison = comparator.compare(baseline: baseline, candidate: candidate)
    }

    private func indexSelectedProject() async {
        guard let project = selectedProject else { return }
        isIndexing = true
        defer { isIndexing = false }
        do {
            let (result, structure) = try await indexer.index(
                project: project,
                store: requireStore(),
                structure: projectStructure
            )
            projectStructure = structure
            if result.imported > 0 {
                statusMessage = "Indexed \(result.imported) new local build\(result.imported == 1 ? "" : "s")."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadProjects() async throws {
        projects = try await requireStore().allProjects()
    }

    @discardableResult
    private func requireStore() throws -> BuildHistoryStore {
        guard let store else {
            throw GradleLensError.database("History store is not ready.")
        }
        return store
    }
}
