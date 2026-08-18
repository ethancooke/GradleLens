import GradleLensCore
import SwiftUI

struct BuildDetailView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Group {
            if let detail = viewModel.selectedDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(detail)
                        if let report = detail.report {
                            phaseSection(report)
                            timelineSection(report)
                            taskSection(report)
                        } else {
                            ContentUnavailableView(
                                "Profile report unavailable",
                                systemImage: "doc.questionmark",
                                description: Text("The HTML file may have been cleaned. The stored metadata is still shown above.")
                            )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyStateView(
                    systemImage: "timeline.selection",
                    title: "No build selected",
                    message: "Choose a local build to inspect its profile timeline and tasks."
                )
            }
        }
        .navigationTitle("Build")
    }

    private func header(_ detail: BuildDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(DurationFormat.display(detail.record.duration))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                StatusBadge(outcome: detail.record.outcome)
                Spacer()
                if let url = detail.record.scanURL ?? detail.record.profileURL {
                    Button(detail.record.scanURL == nil ? "Open Report" : "Open Scan") {
                        WorkspaceOpener.open(url)
                    }
                    Button("Reveal") { WorkspaceOpener.reveal(url) }
                }
            }
            Text(detail.record.requestedTasksLabel)
                .font(.title3)
            HStack(spacing: 16) {
                labeled("Started", detail.record.startedAt.formatted(date: .abbreviated, time: .standard))
                if let version = detail.record.gradleVersion {
                    labeled("Gradle", version)
                }
                if let report = detail.report {
                    labeled("Tasks", "\(report.tasks.count)")
                }
                if detail.scan != nil {
                    labeled("Capture", "Local scan")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private func phaseSection(_ report: ProfileReport) -> some View {
        GroupBox("Phases") {
            PhaseBreakdownView(summary: report.summary)
                .padding(.vertical, 4)
        }
    }

    private func timelineSection(_ report: ProfileReport) -> some View {
        GroupBox("Slowest tasks") {
            if report.tasks.isEmpty {
                Text("No task rows in this profile report.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TimelineView(tasks: report.tasks)
                    .padding(.vertical, 4)
            }
        }
    }

    private func taskSection(_ report: ProfileReport) -> some View {
        let filtered = filteredTasks(report.tasks)
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Filter tasks", text: $viewModel.taskSearch)
                        .textFieldStyle(.roundedBorder)
                    resultSummary(report)
                }
                Table(filtered) {
                    TableColumn("Task") { task in
                        Text(task.path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }
                    .width(min: 220)
                    TableColumn("Duration") { task in
                        Text(DurationFormat.display(task.duration))
                            .font(.body.monospacedDigit())
                    }
                    .width(min: 80, ideal: 90)
                    TableColumn("Result") { task in
                        TaskResultBadge(result: task.result)
                    }
                    .width(min: 110, ideal: 130)
                }
                .frame(minHeight: 260)
            }
        } label: {
            Text("Tasks (\(filtered.count))")
        }
    }

    private func filteredTasks(_ tasks: [ProfileTask]) -> [ProfileTask] {
        let query = viewModel.taskSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = tasks.sorted { $0.duration > $1.duration }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.path.localizedCaseInsensitiveContains(query)
                || $0.result.displayName.localizedCaseInsensitiveContains(query)
                || $0.rawResult.localizedCaseInsensitiveContains(query)
        }
    }

    private func resultSummary(_ report: ProfileReport) -> some View {
        let counts = report.taskCountsByResult
        return HStack(spacing: 8) {
            summaryChip(TaskResult.executed, counts)
            summaryChip(TaskResult.fromCache, counts)
            summaryChip(TaskResult.upToDate, counts)
            summaryChip(TaskResult.failed, counts)
        }
        .font(.caption)
    }

    private func summaryChip(_ result: TaskResult, _ counts: [TaskResult: Int]) -> some View {
        let count = counts[result] ?? 0
        return HStack(spacing: 4) {
            Circle().fill(result.barColor).frame(width: 7, height: 7)
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .help("\(result.displayName): \(count)")
        .accessibilityLabel("\(result.displayName), \(count)")
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
            Text(value)
        }
    }
}
