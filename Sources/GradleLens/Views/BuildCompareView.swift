import GradleLensCore
import SwiftUI

struct BuildCompareView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        if let comparison = viewModel.comparison {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(comparison)
                    phaseSection(comparison)
                    slowerSection(comparison)
                    cacheSection(comparison)
                    appearedSection(comparison)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Compare")
        } else {
            EmptyStateView(
                systemImage: "arrow.left.arrow.right",
                title: "Compare two builds",
                message: "Select a build and choose Compare, or use the context menu to pick a baseline and a candidate."
            )
        }
    }

    private func header(_ comparison: BuildComparison) -> some View {
        let delta = comparison.durationDelta
        let slower = delta > 0.000_5
        let faster = delta < -0.000_5
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(deltaLabel(delta))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(slower ? Color.red : faster ? Color.green : Color.secondary)
                Text(slower ? "slower" : faster ? "faster" : "unchanged")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Swap A/B") {
                    Task { await viewModel.swapComparison() }
                }
                Button("Done") {
                    viewModel.clearComparison()
                }
            }
            HStack(alignment: .top, spacing: 24) {
                compareSide(letter: "A", record: comparison.baseline)
                compareSide(letter: "B", record: comparison.candidate)
            }
        }
    }

    private func compareSide(letter: String, record: BuildRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(letter)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())
                StatusBadge(outcome: record.outcome)
            }
            Text(record.requestedTasksLabel)
                .font(.headline)
            Text(DurationFormat.display(record.duration))
                .font(.title3.monospacedDigit())
            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            if record.hasLocalScan {
                Text("Local scan")
                    .font(.caption)
                    .foregroundStyle(.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseSection(_ comparison: BuildComparison) -> some View {
        GroupBox("Phases") {
            if comparison.phaseDeltas.isEmpty {
                Text("Phase data is only available when a --profile report is attached.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(comparison.phaseDeltas) { phase in
                        HStack {
                            Text(phase.name)
                                .frame(width: 170, alignment: .leading)
                            Text(DurationFormat.display(phase.baseline))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .trailing)
                            Text(DurationFormat.display(phase.candidate))
                                .font(.caption.monospacedDigit())
                                .frame(width: 64, alignment: .trailing)
                            Text(signedDuration(phase.delta))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(deltaColor(phase.delta))
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func slowerSection(_ comparison: BuildComparison) -> some View {
        let rows = comparison.sharedTaskDeltas.filter { ($0.durationDelta ?? 0) != 0 }.prefix(12)
        return GroupBox("Task duration changes") {
            if rows.isEmpty {
                Text("No shared tasks changed duration.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows)) { task in
                        HStack {
                            Text(task.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(signedDuration(task.durationDelta ?? 0))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(deltaColor(task.durationDelta ?? 0))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func cacheSection(_ comparison: BuildComparison) -> some View {
        GroupBox("Cache / up-to-date flips") {
            if comparison.cacheFlips.isEmpty {
                Text("No shared task changed cache or UP-TO-DATE state.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(comparison.cacheFlips) { task in
                        HStack {
                            Text(task.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(task.baselineResult?.displayName ?? "—")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(task.candidateResult?.displayName ?? "—")
                                .font(.caption2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func appearedSection(_ comparison: BuildComparison) -> some View {
        GroupBox("Appeared / disappeared") {
            VStack(alignment: .leading, spacing: 8) {
                labeledList("Only in B", comparison.appeared)
                labeledList("Only in A", comparison.disappeared)
            }
            .padding(.vertical, 4)
        }
    }

    private func labeledList(_ title: String, _ tasks: [ProfileTask]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if tasks.isEmpty {
                Text("None")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks.prefix(8)) { task in
                    HStack {
                        Text(task.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(DurationFormat.display(task.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func deltaLabel(_ delta: TimeInterval) -> String {
        signedDuration(delta)
    }

    private func signedDuration(_ delta: TimeInterval) -> String {
        let prefix = delta > 0 ? "+" : ""
        return prefix + DurationFormat.display(delta)
    }

    private func deltaColor(_ delta: TimeInterval) -> Color {
        if delta > 0.000_5 { return .red }
        if delta < -0.000_5 { return .green }
        return .secondary
    }
}
