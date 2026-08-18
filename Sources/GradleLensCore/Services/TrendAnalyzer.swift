import Foundation

public struct TrendAnalyzer: Sendable {
    public init() {}

    public func commands(in builds: [BuildRecord]) -> [CommandSeries] {
        let grouped = Dictionary(grouping: builds, by: \.commandKey)
        return grouped.map { key, rows in
            let ordered = rows.sorted { $0.startedAt < $1.startedAt }
            let stats = statistics(for: ordered)
            return CommandSeries(
                key: key,
                runCount: ordered.count,
                latestAt: ordered.last?.startedAt ?? .distantPast,
                failureRate: stats.failureRate,
                medianDuration: stats.medianDuration ?? 0,
                recentDurations: Array(ordered.suffix(24).map(\.duration))
            )
        }
        .sorted { lhs, rhs in
            if lhs.latestAt != rhs.latestAt { return lhs.latestAt > rhs.latestAt }
            return lhs.runCount > rhs.runCount
        }
    }

    public func snapshot(
        in builds: [BuildRecord],
        commandKey: String,
        range: TrendRange,
        branch: String?,
        now: Date = .now
    ) -> TrendSnapshot {
        let runs = builds
            .filter { $0.commandKey == commandKey }
            .filter { range.contains($0.startedAt, now: now) }
            .filter { record in
                guard let branch, !branch.isEmpty else { return true }
                return record.gitBranch == branch
            }
            .sorted { $0.startedAt < $1.startedAt }
        let branches = Set(builds.filter { $0.commandKey == commandKey }.compactMap(\.gitBranch))
            .sorted()
        return TrendSnapshot(
            commandKey: commandKey,
            range: range,
            runs: runs,
            stats: statistics(for: runs),
            branches: branches
        )
    }

    public func statistics(for runs: [BuildRecord]) -> TrendStats {
        let succeeded = runs.filter { $0.outcome == .succeeded }.count
        let failed = runs.filter { $0.outcome == .failed }.count
        let unknown = runs.filter { $0.outcome == .unknown }.count
        let durations = runs.map(\.duration).sorted()
        let median = median(durations)
        let latest = runs.last?.duration
        let latestVsMedian: TimeInterval?
        if let latest, let median, median > 0 {
            latestVsMedian = latest - median
        } else {
            latestVsMedian = nil
        }
        return TrendStats(
            count: runs.count,
            succeeded: succeeded,
            failed: failed,
            unknown: unknown,
            failureRate: runs.isEmpty ? 0 : Double(failed) / Double(runs.count),
            minDuration: durations.first,
            maxDuration: durations.last,
            medianDuration: median,
            p95Duration: percentile(durations, 0.95),
            latestDuration: latest,
            latestVsMedian: latestVsMedian
        )
    }

    public func percentile(_ sorted: [TimeInterval], _ fraction: Double) -> TimeInterval? {
        guard !sorted.isEmpty else { return nil }
        if sorted.count == 1 { return sorted[0] }
        let clamped = min(max(fraction, 0), 1)
        let index = Int((Double(sorted.count - 1) * clamped).rounded())
        return sorted[min(max(index, 0), sorted.count - 1)]
    }

    public func median(_ sorted: [TimeInterval]) -> TimeInterval? {
        guard !sorted.isEmpty else { return nil }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
