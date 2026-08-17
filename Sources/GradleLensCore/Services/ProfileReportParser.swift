import Foundation

public struct ProfileReportParser: Sendable {
    public init() {}

    public func parse(fileAt url: URL) throws -> ProfileReport {
        let html: String
        do {
            html = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw GradleLensError.profileParseFailed("Unable to read \(url.path): \(error.localizedDescription)")
        }
        return try parse(html: html, sourcePath: url.path)
    }

    public func parse(html: String, sourcePath: String) throws -> ProfileReport {
        let sections = HTMLSupport.headingTables(in: html)
        guard let summaryRows = sections["Summary"], !summaryRows.isEmpty else {
            throw GradleLensError.profileParseFailed("Missing Summary table")
        }

        let summaryMap = Dictionary(
            uniqueKeysWithValues: summaryRows.compactMap { row -> (String, TimeInterval)? in
                guard row.count >= 2, let duration = DurationFormat.parseGradle(row[1]) else { return nil }
                return (row[0], duration)
            }
        )

        let summary = ProfileSummary(
            totalBuildTime: summaryMap["Total Build Time"] ?? 0,
            startup: summaryMap["Startup"] ?? 0,
            settingsAndBuildSrc: summaryMap["Settings and buildSrc"] ?? 0,
            loadingProjects: summaryMap["Loading Projects"] ?? 0,
            configuringProjects: summaryMap["Configuring Projects"] ?? 0,
            artifactTransforms: summaryMap["Artifact Transforms"] ?? 0,
            taskExecution: summaryMap["Task Execution"] ?? 0
        )

        let configuration = namedDurations(in: sections["Configuration"] ?? [], skippingFirstIfNamed: "All projects")
        let dependencies = namedDurations(in: sections["Dependency Resolution"] ?? [], skippingFirstIfNamed: "All dependencies")
        let transforms = namedDurations(in: sections["Artifact Transforms"] ?? [], skippingFirstIfNamed: "All transforms")

        var projectTotals: [NamedDuration] = []
        var tasks: [ProfileTask] = []
        for row in sections["Task Execution"] ?? [] {
            guard row.count >= 2, let duration = DurationFormat.parseGradle(row[1]) else { continue }
            let name = row[0]
            let resultText = row.count >= 3 ? row[2] : ""
            if resultText == "(total)" {
                projectTotals.append(NamedDuration(name: name, duration: duration))
            } else {
                tasks.append(
                    ProfileTask(
                        path: name,
                        duration: duration,
                        result: TaskResult.parse(resultText),
                        rawResult: resultText
                    )
                )
            }
        }

        let paragraphs = HTMLSupport.firstParagraphs(in: html)
        let requestedTasks = parseRequestedTasks(from: paragraphs)
        let startedAt = parseStartedAt(from: paragraphs) ?? timestampFromFilename(sourcePath) ?? .now

        return ProfileReport(
            sourcePath: sourcePath,
            startedAt: startedAt,
            requestedTasks: requestedTasks,
            summary: summary,
            configuration: configuration,
            dependencyResolution: dependencies,
            artifactTransforms: transforms,
            projectTotals: projectTotals,
            tasks: tasks
        )
    }

    private func namedDurations(in rows: [[String]], skippingFirstIfNamed name: String) -> [NamedDuration] {
        rows.compactMap { row in
            guard row.count >= 2, let duration = DurationFormat.parseGradle(row[1]) else { return nil }
            if row[0] == name { return nil }
            return NamedDuration(name: row[0], duration: duration)
        }
    }

    private func parseRequestedTasks(from paragraphs: [String]) -> [String] {
        guard
            let line = paragraphs.first(where: { $0.hasPrefix("Profiled build:") })
        else { return [] }
        let raw = line.dropFirst("Profiled build:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "(no tasks specified)" { return [] }
        return raw.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func parseStartedAt(from paragraphs: [String]) -> Date? {
        guard
            let line = paragraphs.first(where: { $0.hasPrefix("Started on:") })
        else { return nil }
        let raw = line.dropFirst("Started on:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy/MM/dd - HH:mm:ss"
        return formatter.date(from: raw)
    }

    private func timestampFromFilename(_ path: String) -> Date? {
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let match = name.range(of: #"\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}"#, options: .regularExpression) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.date(from: String(name[match]))
    }
}
