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
    private let scanParser: LocalScanParser
    private let structureReader: ProjectStructureReader

    public init(
        parser: ProfileReportParser = ProfileReportParser(),
        scanParser: LocalScanParser = LocalScanParser(),
        structureReader: ProjectStructureReader = ProjectStructureReader()
    ) {
        self.parser = parser
        self.scanParser = scanParser
        self.structureReader = structureReader
    }

    public func index(
        project: GradleProject,
        store: BuildHistoryStore,
        structure: ProjectStructure? = nil
    ) async throws -> (IndexResult, ProjectStructure) {
        let resolved = try structure ?? structureReader.read(projectRoot: project.rootURL)
        let profiles = reportFiles(in: project.rootURL, structure: resolved, prefix: "profile-", ext: "html")
        let scans = reportFiles(in: project.rootURL, structure: resolved, prefix: "scan-", ext: "json", extraFolder: "gradlelens")
        let gradleVersion = resolved.gradleVersion

        var parsedProfiles: [(url: URL, report: ProfileReport)] = []
        for url in profiles {
            if let report = try? parser.parse(fileAt: url) {
                parsedProfiles.append((url, report))
            }
        }

        var imported = 0
        var skipped = 0
        var failed = 0
        var claimedProfiles = Set<String>()

        for scanURL in scans {
            do {
                let scan = try scanParser.parse(fileAt: scanURL)
                let match = nearestProfile(to: scan.startedAt, in: parsedProfiles, claimed: claimedProfiles)
                if let match {
                    claimedProfiles.insert(match.url.path)
                }
                var alreadyIndexed = try await store.containsSource(scan.sourcePath)
                if !alreadyIndexed, let match {
                    alreadyIndexed = try await store.containsSource(match.url.path)
                }
                if alreadyIndexed {
                    let record = makeRecord(
                        project: project,
                        scan: scan,
                        profile: match?.report,
                        profilePath: match?.url.path,
                        fallbackGradle: gradleVersion
                    )
                    try await store.upsertBuild(record)
                    skipped += 1
                    continue
                }
                let record = makeRecord(
                    project: project,
                    scan: scan,
                    profile: match?.report,
                    profilePath: match?.url.path,
                    fallbackGradle: gradleVersion
                )
                try await store.upsertBuild(record)
                imported += 1
            } catch {
                failed += 1
            }
        }

        for item in parsedProfiles where !claimedProfiles.contains(item.url.path) {
            do {
                if try await store.containsSource(item.url.path) {
                    skipped += 1
                    continue
                }
                let record = BuildRecord(
                    projectID: project.id,
                    startedAt: item.report.startedAt,
                    duration: item.report.summary.totalBuildTime,
                    outcome: item.report.outcome,
                    requestedTasks: item.report.requestedTasks,
                    gradleVersion: gradleVersion,
                    profilePath: item.report.sourcePath
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
        let scan = record.scanPath.flatMap { try? scanParser.parse(fileAt: URL(fileURLWithPath: $0)) }
        let profile = record.profilePath.flatMap { try? parser.parse(fileAt: URL(fileURLWithPath: $0)) }
        return BuildDetail(
            record: record,
            report: CaptureMerge.report(profile: profile, scan: scan),
            scan: scan
        )
    }

    public func profileReports(in projectRoot: URL, structure: ProjectStructure) -> [URL] {
        reportFiles(in: projectRoot, structure: structure, prefix: "profile-", ext: "html")
    }

    private func makeRecord(
        project: GradleProject,
        scan: LocalScan,
        profile: ProfileReport?,
        profilePath: String?,
        fallbackGradle: String?
    ) -> BuildRecord {
        BuildRecord(
            projectID: project.id,
            startedAt: scan.startedAt,
            duration: scan.duration > 0 ? scan.duration : (profile?.summary.totalBuildTime ?? 0),
            outcome: scan.outcome,
            requestedTasks: scan.requestedTasks.isEmpty ? (profile?.requestedTasks ?? []) : scan.requestedTasks,
            gradleVersion: scan.gradleVersion ?? fallbackGradle,
            profilePath: profilePath ?? profile?.sourcePath,
            scanPath: scan.sourcePath,
            gitBranch: scan.git?.branch,
            gitCommit: scan.git?.commit
        )
    }

    private func nearestProfile(
        to date: Date,
        in profiles: [(url: URL, report: ProfileReport)],
        claimed: Set<String>
    ) -> (url: URL, report: ProfileReport)? {
        let window: TimeInterval = 30
        return profiles
            .filter { !claimed.contains($0.url.path) }
            .map { ($0, abs($0.report.startedAt.timeIntervalSince(date))) }
            .filter { $0.1 <= window }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func reportFiles(
        in projectRoot: URL,
        structure: ProjectStructure,
        prefix: String,
        ext: String,
        extraFolder: String? = nil
    ) -> [URL] {
        var directories: [URL] = [
            projectRoot.appendingPathComponent("build/reports/profile", isDirectory: true)
        ]
        if let extraFolder {
            directories.append(
                projectRoot.appendingPathComponent("build/reports/\(extraFolder)", isDirectory: true)
            )
        }
        for module in structure.modules where module.directory != "." {
            let moduleRoot = projectRoot.appendingPathComponent(module.directory, isDirectory: true)
            directories.append(moduleRoot.appendingPathComponent("build/reports/profile", isDirectory: true))
            if let extraFolder {
                directories.append(moduleRoot.appendingPathComponent("build/reports/\(extraFolder)", isDirectory: true))
            }
        }

        var files: [URL] = []
        for directory in directories {
            guard
                let items = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }
            files.append(
                contentsOf: items.filter {
                    $0.pathExtension.lowercased() == ext && $0.lastPathComponent.hasPrefix(prefix)
                }
            )
        }

        return files.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
    }
}
