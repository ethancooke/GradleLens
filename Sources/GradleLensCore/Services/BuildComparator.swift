import Foundation

public struct PhaseDelta: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let baseline: TimeInterval
    public let candidate: TimeInterval

    public init(name: String, baseline: TimeInterval, candidate: TimeInterval) {
        self.name = name
        self.baseline = baseline
        self.candidate = candidate
    }

    public var delta: TimeInterval { candidate - baseline }
}

public struct TaskDelta: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public let path: String
    public let baselineDuration: TimeInterval?
    public let candidateDuration: TimeInterval?
    public let baselineResult: TaskResult?
    public let candidateResult: TaskResult?

    public init(
        path: String,
        baselineDuration: TimeInterval?,
        candidateDuration: TimeInterval?,
        baselineResult: TaskResult?,
        candidateResult: TaskResult?
    ) {
        self.path = path
        self.baselineDuration = baselineDuration
        self.candidateDuration = candidateDuration
        self.baselineResult = baselineResult
        self.candidateResult = candidateResult
    }

    public var durationDelta: TimeInterval? {
        guard let baselineDuration, let candidateDuration else { return nil }
        return candidateDuration - baselineDuration
    }

    public var cacheFlipped: Bool {
        guard let baselineResult, let candidateResult else { return false }
        let cacheLike: Set<TaskResult> = [.fromCache, .upToDate]
        return cacheLike.contains(baselineResult) != cacheLike.contains(candidateResult)
            || (baselineResult == .fromCache) != (candidateResult == .fromCache)
    }
}

public struct BuildComparison: Sendable, Hashable {
    public let baseline: BuildRecord
    public let candidate: BuildRecord
    public let durationDelta: TimeInterval
    public let phaseDeltas: [PhaseDelta]
    public let sharedTaskDeltas: [TaskDelta]
    public let appeared: [ProfileTask]
    public let disappeared: [ProfileTask]
    public let cacheFlips: [TaskDelta]

    public init(
        baseline: BuildRecord,
        candidate: BuildRecord,
        durationDelta: TimeInterval,
        phaseDeltas: [PhaseDelta],
        sharedTaskDeltas: [TaskDelta],
        appeared: [ProfileTask],
        disappeared: [ProfileTask],
        cacheFlips: [TaskDelta]
    ) {
        self.baseline = baseline
        self.candidate = candidate
        self.durationDelta = durationDelta
        self.phaseDeltas = phaseDeltas
        self.sharedTaskDeltas = sharedTaskDeltas
        self.appeared = appeared
        self.disappeared = disappeared
        self.cacheFlips = cacheFlips
    }
}

public struct BuildComparator: Sendable {
    public init() {}

    public func compare(baseline: BuildDetail, candidate: BuildDetail) -> BuildComparison {
        let baseReport = baseline.report
        let candReport = candidate.report
        let baseTasks = Dictionary(uniqueKeysWithValues: (baseReport?.tasks ?? []).map { ($0.path, $0) })
        let candTasks = Dictionary(uniqueKeysWithValues: (candReport?.tasks ?? []).map { ($0.path, $0) })
        let baseKeys = Set(baseTasks.keys)
        let candKeys = Set(candTasks.keys)

        let shared = baseKeys.intersection(candKeys).map { path -> TaskDelta in
            let left = baseTasks[path]!
            let right = candTasks[path]!
            return TaskDelta(
                path: path,
                baselineDuration: left.duration,
                candidateDuration: right.duration,
                baselineResult: left.result,
                candidateResult: right.result
            )
        }
        .sorted { abs($0.durationDelta ?? 0) > abs($1.durationDelta ?? 0) }

        let appeared = candKeys.subtracting(baseKeys).compactMap { candTasks[$0] }
            .sorted { $0.duration > $1.duration }
        let disappeared = baseKeys.subtracting(candKeys).compactMap { baseTasks[$0] }
            .sorted { $0.duration > $1.duration }
        let flips = shared.filter(\.cacheFlipped)

        let phases: [PhaseDelta]
        if let left = baseReport?.summary, let right = candReport?.summary {
            phases = zip(left.phases, right.phases).map { lhs, rhs in
                PhaseDelta(name: lhs.name, baseline: lhs.duration, candidate: rhs.duration)
            }
        } else {
            phases = []
        }

        return BuildComparison(
            baseline: baseline.record,
            candidate: candidate.record,
            durationDelta: candidate.record.duration - baseline.record.duration,
            phaseDeltas: phases,
            sharedTaskDeltas: shared,
            appeared: appeared,
            disappeared: disappeared,
            cacheFlips: flips
        )
    }
}
