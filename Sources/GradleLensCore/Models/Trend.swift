import Foundation

public enum CommandKey: Sendable {
    public static func make(_ tasks: [String]) -> String {
        let parts = tasks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "(default tasks)" : parts.joined(separator: " ")
    }
}

public enum TrendPreset: String, Sendable, CaseIterable, Identifiable {
    case day
    case week
    case month
    case quarter
    case year
    case all
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .day: "24 hours"
        case .week: "7 days"
        case .month: "30 days"
        case .quarter: "90 days"
        case .year: "1 year"
        case .all: "All"
        case .custom: "Custom"
        }
    }
}

public struct TrendRange: Sendable, Equatable, Hashable {
    public var preset: TrendPreset
    public var customStart: Date
    public var customEnd: Date

    public init(
        preset: TrendPreset = .month,
        customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now,
        customEnd: Date = .now
    ) {
        self.preset = preset
        self.customStart = customStart
        self.customEnd = customEnd
    }

    public func bounds(now: Date = .now) -> (start: Date?, end: Date?) {
        switch preset {
        case .day:
            (Calendar.current.date(byAdding: .hour, value: -24, to: now), now)
        case .week:
            (Calendar.current.date(byAdding: .day, value: -7, to: now), now)
        case .month:
            (Calendar.current.date(byAdding: .day, value: -30, to: now), now)
        case .quarter:
            (Calendar.current.date(byAdding: .day, value: -90, to: now), now)
        case .year:
            (Calendar.current.date(byAdding: .year, value: -1, to: now), now)
        case .all:
            (nil, nil)
        case .custom:
            (min(customStart, customEnd), max(customStart, customEnd))
        }
    }

    public func contains(_ date: Date, now: Date = .now) -> Bool {
        let (start, end) = bounds(now: now)
        if let start, date < start { return false }
        if let end, date > end { return false }
        return true
    }
}

public struct TrendStats: Sendable, Hashable {
    public let count: Int
    public let succeeded: Int
    public let failed: Int
    public let unknown: Int
    public let failureRate: Double
    public let minDuration: TimeInterval?
    public let maxDuration: TimeInterval?
    public let medianDuration: TimeInterval?
    public let p95Duration: TimeInterval?
    public let latestDuration: TimeInterval?
    public let latestVsMedian: TimeInterval?

    public init(
        count: Int,
        succeeded: Int,
        failed: Int,
        unknown: Int,
        failureRate: Double,
        minDuration: TimeInterval?,
        maxDuration: TimeInterval?,
        medianDuration: TimeInterval?,
        p95Duration: TimeInterval?,
        latestDuration: TimeInterval?,
        latestVsMedian: TimeInterval?
    ) {
        self.count = count
        self.succeeded = succeeded
        self.failed = failed
        self.unknown = unknown
        self.failureRate = failureRate
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.medianDuration = medianDuration
        self.p95Duration = p95Duration
        self.latestDuration = latestDuration
        self.latestVsMedian = latestVsMedian
    }

    public var isEmpty: Bool { count == 0 }
}

public struct CommandSeries: Sendable, Identifiable, Hashable {
    public var id: String { key }
    public let key: String
    public let runCount: Int
    public let latestAt: Date
    public let failureRate: Double
    public let medianDuration: TimeInterval
    public let recentDurations: [TimeInterval]

    public init(
        key: String,
        runCount: Int,
        latestAt: Date,
        failureRate: Double,
        medianDuration: TimeInterval,
        recentDurations: [TimeInterval]
    ) {
        self.key = key
        self.runCount = runCount
        self.latestAt = latestAt
        self.failureRate = failureRate
        self.medianDuration = medianDuration
        self.recentDurations = recentDurations
    }
}

public struct TrendSnapshot: Sendable, Hashable {
    public let commandKey: String
    public let range: TrendRange
    public let runs: [BuildRecord]
    public let stats: TrendStats
    public let branches: [String]

    public init(commandKey: String, range: TrendRange, runs: [BuildRecord], stats: TrendStats, branches: [String]) {
        self.commandKey = commandKey
        self.range = range
        self.runs = runs
        self.stats = stats
        self.branches = branches
    }
}

public extension BuildRecord {
    var commandKey: String { CommandKey.make(requestedTasks) }
}
