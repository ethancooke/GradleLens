import Foundation

public struct IndexResult: Sendable, Equatable {
    public let imported: Int
    public let skippedExisting: Int
    public let failed: Int

    public init(imported: Int, skippedExisting: Int, failed: Int) {
        self.imported = imported
        self.skippedExisting = skippedExisting
        self.failed = failed
    }

    public var examined: Int { imported + skippedExisting + failed }
}

public actor BuildIndexer {
    private let parser: ProfileReportParser
    private let structureReader: ProjectStructureReader

    public init(
        parser: ProfileReportParser = ProfileReportParser(),
        structureReader: ProjectStructureReader = ProjectStructureReader()
    ) {
        self.parser = parser
        self.structureReader = structureReader
    }

    public func index(
        project: GradleProject,
        store: BuildHistoryStore,
        structure: ProjectStructure? = nil
    ) async throws -> (IndexResult, ProjectStructure) {
        let resolved = try structure ?? structureReader.read(projectRoot: project.rootURL)
        let reports = profileReports(in: project.rootURL, structure: resolved)
        let gradleVersion = resolved.gradleVersion
        var imported = 0
        var skipped = 0
        var failed = 0

        for reportURL in reports {
            do {
                if try await store.containsProfile(path: reportURL.path) {
                    skipped += 1
                    continue
                }
                let report = try parser.parse(fileAt: reportURL)
                let record = BuildRecord(
                    projectID: project.id,
                    startedAt: report.startedAt,
                    duration: report.summary.totalBuildTime,
                    outcome: report.outcome,
                    requestedTasks: report.requestedTasks,
                    gradleVersion: gradleVersion,
                    profilePath: report.sourcePath
                )
                try await store.upsertBuild(record)
                imported += 1
            } catch {
                failed += 1
            }
        }

        let updated = project.touchingIndexed()
        try await store.upsertProject(updated)
        return (IndexResult(imported: imported, skippedExisting: skipped, failed: failed), resolved)
    }

    public func loadDetail(for record: BuildRecord) -> BuildDetail {
        guard let path = record.profilePath else {
            return BuildDetail(record: record, report: nil)
        }
        let url = URL(fileURLWithPath: path)
        let report = try? parser.parse(fileAt: url)
        return BuildDetail(record: record, report: report)
    }

    public func profileReports(in projectRoot: URL, structure: ProjectStructure) -> [URL] {
        var directories: [URL] = [projectRoot.appendingPathComponent("build/reports/profile", isDirectory: true)]
        for module in structure.modules where module.directory != "." {
            directories.append(
                projectRoot
                    .appendingPathComponent(module.directory, isDirectory: true)
                    .appendingPathComponent("build/reports/profile", isDirectory: true)
            )
        }

        var reports: [URL] = []
        for directory in directories {
            guard
                let items = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }
            reports.append(
                contentsOf: items.filter {
                    $0.pathExtension.lowercased() == "html" && $0.lastPathComponent.hasPrefix("profile-")
                }
            )
        }

        return reports.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
    }
}
