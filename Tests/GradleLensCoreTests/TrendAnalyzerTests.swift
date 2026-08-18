import Foundation
import Testing

@testable import GradleLensCore

@Suite("CommandKey")
struct CommandKeyTests {
    @Test("Normalizes requested tasks")
    func normalize() {
        #expect(CommandKey.make(["assemble"]) == "assemble")
        #expect(CommandKey.make(["clean", "build"]) == "clean build")
        #expect(CommandKey.make([]) == "(default tasks)")
        #expect(CommandKey.make(["  assemble  ", ""]) == "assemble")
    }
}

@Suite("TrendRange")
struct TrendRangeTests {
    @Test("Presets bound the window")
    func presets() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let week = TrendRange(preset: .week).bounds(now: now)
        #expect(week.end == now)
        #expect(week.start == Calendar.current.date(byAdding: .day, value: -7, to: now))

        let all = TrendRange(preset: .all).bounds(now: now)
        #expect(all.start == nil)
        #expect(all.end == nil)

        var custom = TrendRange(preset: .custom)
        custom.customStart = Date(timeIntervalSince1970: 10)
        custom.customEnd = Date(timeIntervalSince1970: 50)
        #expect(TrendRange(preset: .custom, customStart: custom.customStart, customEnd: custom.customEnd)
            .contains(Date(timeIntervalSince1970: 30)))
        #expect(!TrendRange(preset: .custom, customStart: custom.customStart, customEnd: custom.customEnd)
            .contains(Date(timeIntervalSince1970: 80)))
    }
}

@Suite("TrendAnalyzer")
struct TrendAnalyzerTests {
    @Test("Groups commands and computes stats")
    func groupsAndStats() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let builds = [
            record("assemble", at: now.addingTimeInterval(-4000), duration: 10, outcome: .succeeded),
            record("assemble", at: now.addingTimeInterval(-3000), duration: 12, outcome: .succeeded),
            record("assemble", at: now.addingTimeInterval(-2000), duration: 20, outcome: .failed),
            record("test", at: now.addingTimeInterval(-1000), duration: 8, outcome: .succeeded),
        ]
        let analyzer = TrendAnalyzer()
        let commands = analyzer.commands(in: builds)
        #expect(commands.map(\.key) == ["test", "assemble"])
        #expect(commands.first { $0.key == "assemble" }?.runCount == 3)

        var range = TrendRange(preset: .all)
        let snapshot = analyzer.snapshot(in: builds, commandKey: "assemble", range: range, branch: nil, now: now)
        #expect(snapshot.runs.count == 3)
        #expect(snapshot.stats.failed == 1)
        #expect(abs(snapshot.stats.failureRate - (1.0 / 3.0)) < 0.000_1)
        #expect(snapshot.stats.medianDuration == 12) // 3 samples: 10, 12, 20
        #expect(snapshot.stats.minDuration == 10)
        #expect(snapshot.stats.maxDuration == 20)
        #expect(snapshot.stats.latestDuration == 20)
        #expect(snapshot.stats.latestVsMedian == 8)

        range.preset = .custom
        range.customStart = now.addingTimeInterval(-3500)
        range.customEnd = now.addingTimeInterval(-1500)
        let sliced = analyzer.snapshot(in: builds, commandKey: "assemble", range: range, branch: nil, now: now)
        #expect(sliced.runs.count == 2)
        #expect(sliced.runs.map(\.duration) == [12, 20])
    }

    @Test("Filters by branch")
    func branchFilter() {
        let now = Date()
        let builds = [
            record("assemble", at: now.addingTimeInterval(-20), duration: 10, outcome: .succeeded, branch: "main"),
            record("assemble", at: now.addingTimeInterval(-10), duration: 30, outcome: .succeeded, branch: "feature"),
        ]
        let snapshot = TrendAnalyzer().snapshot(
            in: builds,
            commandKey: "assemble",
            range: TrendRange(preset: .all),
            branch: "main",
            now: now
        )
        #expect(snapshot.runs.count == 1)
        #expect(snapshot.runs.first?.duration == 10)
        #expect(snapshot.branches == ["feature", "main"])
    }

    private func record(
        _ command: String,
        at date: Date,
        duration: TimeInterval,
        outcome: BuildOutcome,
        branch: String? = nil
    ) -> BuildRecord {
        BuildRecord(
            projectID: "/tmp/p",
            startedAt: date,
            duration: duration,
            outcome: outcome,
            requestedTasks: command.split(separator: " ").map(String.init),
            gitBranch: branch
        )
    }
}
