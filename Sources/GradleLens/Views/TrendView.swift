import Charts
import GradleLensCore
import SwiftUI

struct TrendView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.commandSeries.isEmpty {
                EmptyStateView(
                    systemImage: "chart.xyaxis.line",
                    title: "No runs to chart",
                    message: "Index some local builds first. Trends group the same Gradle command over the range you pick."
                )
            } else if let snapshot = viewModel.trendSnapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(snapshot)
                        rangeBar
                        statsRow(snapshot.stats)
                        durationChart(snapshot)
                        outcomeStrip(snapshot)
                        runTable(snapshot)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Trends")
        .navigationSubtitle(viewModel.selectedCommandOrDefault ?? "")
    }

    private func header(_ snapshot: TrendSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.commandKey)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                Button("Close") {
                    viewModel.showingTrends = false
                }
            }
            if snapshot.stats.count >= 2, let delta = snapshot.stats.latestVsMedian {
                let slower = delta > 0.000_5
                Text(slower
                     ? "Latest run is \(DurationFormat.display(delta)) slower than the median in this range."
                     : "Latest run is \(DurationFormat.display(abs(delta))) faster than the median in this range.")
                    .foregroundStyle(slower ? Color.orange : Color.green)
            }
        }
    }

    private var rangeBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Range", selection: $viewModel.trendRange.preset) {
                ForEach(TrendPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if viewModel.trendRange.preset == .custom {
                HStack {
                    DatePicker("From", selection: $viewModel.trendRange.customStart, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("To", selection: $viewModel.trendRange.customEnd, displayedComponents: [.date, .hourAndMinute])
                }
            }

            if let snapshot = viewModel.trendSnapshot, !snapshot.branches.isEmpty {
                Picker("Branch", selection: $viewModel.trendBranch) {
                    Text("All branches").tag(Optional<String>.none)
                    ForEach(snapshot.branches, id: \.self) { branch in
                        Text(branch).tag(Optional(branch))
                    }
                }
                .frame(maxWidth: 260)
            }
        }
    }

    private func statsRow(_ stats: TrendStats) -> some View {
        HStack(spacing: 16) {
            stat("Runs", "\(stats.count)")
            stat("Failed", "\(stats.failed)")
            stat("Fail rate", stats.count == 0 ? "—" : stats.failureRate.formatted(.percent.precision(.fractionLength(0))))
            stat("Median", stats.medianDuration.map(DurationFormat.display) ?? "—")
            stat("Fastest", stats.minDuration.map(DurationFormat.display) ?? "—")
            stat("Slowest", stats.maxDuration.map(DurationFormat.display) ?? "—")
            stat("p95", stats.p95Duration.map(DurationFormat.display) ?? "—")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit().weight(.medium))
        }
        .frame(minWidth: 64, alignment: .leading)
    }

    private func durationChart(_ snapshot: TrendSnapshot) -> some View {
        GroupBox("Duration") {
            if snapshot.runs.count < 2 {
                Text("Need at least two runs in this range to chart a trend.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Chart(snapshot.runs) { run in
                    LineMark(
                        x: .value("When", run.startedAt),
                        y: .value("Duration", run.duration)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor.opacity(0.55))

                    PointMark(
                        x: .value("When", run.startedAt),
                        y: .value("Duration", run.duration)
                    )
                    .foregroundStyle(pointColor(run.outcome))
                    .symbolSize(run.id == viewModel.selectedBuildID ? 80 : 40)

                    if let median = snapshot.stats.medianDuration {
                        RuleMark(y: .value("Median", median))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("median \(DurationFormat.display(median))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let seconds = value.as(TimeInterval.self) {
                                Text(DurationFormat.display(seconds))
                            }
                        }
                    }
                }
                .frame(minHeight: 220)
                .padding(.vertical, 8)
            }
        }
    }

    private func outcomeStrip(_ snapshot: TrendSnapshot) -> some View {
        GroupBox("Outcomes") {
            if snapshot.runs.isEmpty {
                Text("No runs in this range.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(snapshot.runs) { run in
                    PointMark(
                        x: .value("When", run.startedAt),
                        y: .value("Outcome", 1)
                    )
                    .foregroundStyle(pointColor(run.outcome))
                    .symbolSize(48)
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...2)
                .frame(height: 44)
                .padding(.vertical, 4)
            }
        }
    }

    private func runTable(_ snapshot: TrendSnapshot) -> some View {
        GroupBox("Runs (\(snapshot.runs.count))") {
            Table(snapshot.runs.reversed(), selection: runSelection) {
                TableColumn("When") { run in
                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .width(min: 140)
                TableColumn("Duration") { run in
                    Text(DurationFormat.display(run.duration))
                        .font(.body.monospacedDigit())
                }
                .width(min: 80)
                TableColumn("Result") { run in
                    StatusBadge(outcome: run.outcome)
                }
                .width(min: 90)
                TableColumn("Branch") { run in
                    Text(run.gitBranch ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)
        }
    }

    private var runSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedBuildID },
            set: { newValue in
                Task { await viewModel.selectBuild(newValue) }
            }
        )
    }

    private func pointColor(_ outcome: BuildOutcome) -> Color {
        switch outcome {
        case .succeeded: .green
        case .failed: .red
        case .unknown: .secondary
        }
    }
}

struct DurationSparkline: View {
    let durations: [TimeInterval]

    var body: some View {
        Chart(Array(durations.enumerated()), id: \.offset) { item in
            LineMark(
                x: .value("i", item.offset),
                y: .value("d", item.element)
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(width: 56, height: 18)
        .accessibilityHidden(true)
    }
}
