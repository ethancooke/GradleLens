import Foundation
import Testing

@testable import GradleLensCore

@Suite("ProfileReportParser")
struct ProfileReportParserTests {
    @Test("Parses a Gradle --profile HTML report")
    func parseFixture() throws {
        let url = try fixtureURL("sample-profile", extension: "html")
        let report = try ProfileReportParser().parse(fileAt: url)

        #expect(report.requestedTasks == ["assemble", "test"])
        #expect(report.summary.totalBuildTime == 12.345)
        #expect(report.summary.startup == 0.234)
        #expect(report.summary.taskExecution == 10.0)
        #expect(report.configuration.map(\.name) == [":app", ":lib"])
        #expect(report.dependencyResolution.count == 2)
        #expect(report.artifactTransforms.map(\.name) == ["IdentityTransform"])
        #expect(report.projectTotals.count == 1)
        #expect(report.tasks.count == 5)
        #expect(report.tasks[0].path == ":app:compileKotlin")
        #expect(report.tasks[0].result == .executed)
        #expect(report.tasks[1].result == .fromCache)
        #expect(report.tasks[2].result == .upToDate)
        #expect(report.tasks[4].result == .skipped)
        #expect(report.outcome == .succeeded)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: report.startedAt)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 17)
        #expect(components.hour == 9)
        #expect(components.minute == 30)
        #expect(components.second == 45)
    }

    @Test("Infers failure from a FAILED task")
    func failedOutcome() throws {
        let html = """
            <h2>Summary</h2>
            <table>
            <tr><td>Total Build Time</td><td>1.000s</td></tr>
            <tr><td>Startup</td><td>0s</td></tr>
            <tr><td>Settings and buildSrc</td><td>0s</td></tr>
            <tr><td>Loading Projects</td><td>0s</td></tr>
            <tr><td>Configuring Projects</td><td>0s</td></tr>
            <tr><td>Artifact Transforms</td><td>0s</td></tr>
            <tr><td>Task Execution</td><td>1.000s</td></tr>
            </table>
            <h2>Task Execution</h2>
            <table>
            <tr><td>:app:test</td><td>1.000s</td><td>FAILED</td></tr>
            </table>
            """
        let report = try ProfileReportParser().parse(html: html, sourcePath: "/tmp/profile.html")
        #expect(report.outcome == .failed)
        #expect(report.tasks.first?.result == .failed)
    }

    @Test("Falls back to the filename timestamp")
    func filenameTimestamp() throws {
        let html = """
            <h2>Summary</h2>
            <table>
            <tr><td>Total Build Time</td><td>0s</td></tr>
            <tr><td>Startup</td><td>0s</td></tr>
            <tr><td>Settings and buildSrc</td><td>0s</td></tr>
            <tr><td>Loading Projects</td><td>0s</td></tr>
            <tr><td>Configuring Projects</td><td>0s</td></tr>
            <tr><td>Artifact Transforms</td><td>0s</td></tr>
            <tr><td>Task Execution</td><td>0s</td></tr>
            </table>
            """
        let report = try ProfileReportParser().parse(
            html: html,
            sourcePath: "/tmp/profile-2025-01-02-03-04-05.html"
        )
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: report.startedAt
        )
        #expect(components.year == 2025)
        #expect(components.month == 1)
        #expect(components.day == 2)
        #expect(components.hour == 3)
        #expect(components.minute == 4)
        #expect(components.second == 5)
    }

    @Test("Rejects HTML without a Summary table")
    func missingSummary() {
        #expect(throws: GradleLensError.self) {
            try ProfileReportParser().parse(html: "<html></html>", sourcePath: "/tmp/x.html")
        }
    }
}

@Suite("DurationFormat")
struct DurationFormatTests {
    @Test("Parses Gradle terse durations")
    func parseGradle() {
        #expect(DurationFormat.parseGradle("0s") == 0)
        #expect(DurationFormat.parseGradle("12.345s") == 12.345)
        #expect(DurationFormat.parseGradle("1m12.34s") == 72.34)
        #expect(abs((DurationFormat.parseGradle("1h2m3.00s") ?? -1) - 3723.0) < 0.001)
        #expect(DurationFormat.parseGradle("250ms") == 0.25)
        #expect(DurationFormat.parseGradle("nope") == nil)
    }

    @Test("Formats durations for display")
    func display() {
        #expect(DurationFormat.display(0) == "0ms")
        #expect(DurationFormat.display(0.12) == "120ms")
        #expect(DurationFormat.display(1.5) == "1.50s")
        #expect(DurationFormat.display(65.2).contains("1m"))
    }
}

func fixtureURL(_ name: String, extension ext: String) throws -> URL {
    let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
        ?? Bundle.module.url(forResource: name, withExtension: ext)
    guard let url else {
        throw GradleLensError.io("Missing fixture \(name).\(ext)")
    }
    return url
}
