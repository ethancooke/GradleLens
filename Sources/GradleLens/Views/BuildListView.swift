import GradleLensCore
import SwiftUI

struct BuildListView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.selectedProject == nil {
                EmptyStateView(
                    systemImage: "hammer",
                    title: "Select a project",
                    message: "Open a Gradle project or import one from your local IDE recents."
                )
            } else if viewModel.projectMissingFromDisk {
                EmptyStateView(
                    systemImage: "internaldrive",
                    title: "Project is missing",
                    message: "This path is no longer on disk. Remove it from the list or open the project again.",
                    actionTitle: "Remove from List"
                ) {
                    if let id = viewModel.selectedProjectID {
                        Task { await viewModel.removeProject(id) }
                    }
                }
            } else if viewModel.filteredBuilds.isEmpty {
                EmptyStateView(
                    systemImage: "chart.bar.doc.horizontal",
                    title: "No local builds yet",
                    message: """
                    GradleLens reads --profile HTML and GradleLens scan JSON.

                    ./gradlew --profile <tasks>
                    """
                )
            } else {
                List(selection: buildSelection) {
                    ForEach(viewModel.filteredBuilds) { build in
                        BuildRow(
                            build: build,
                            role: compareRole(for: build.id)
                        )
                        .tag(build.id)
                        .contextMenu {
                            Button("Compare with another build") {
                                Task { await viewModel.markForCompare(build.id) }
                            }
                            if viewModel.selectedBuildID == build.id {
                                Button("Compare with previous") {
                                    Task { await viewModel.compareWithPrevious() }
                                }
                            }
                            Button("Trends for this command") {
                                viewModel.showTrends(for: build.commandKey)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.selectedProject?.name ?? "Builds")
        .navigationSubtitle(subtitle)
        .searchable(text: $viewModel.searchText, prompt: "Filter builds")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Trends") {
                    viewModel.showTrends()
                }
                .help("Chart this command over a date range")
                .disabled(viewModel.builds.isEmpty)
            }
            ToolbarItem(placement: .automatic) {
                if viewModel.comparison != nil {
                    Button("Clear compare") {
                        viewModel.clearComparison()
                    }
                } else if viewModel.selectedBuildID != nil {
                    Button("Compare") {
                        Task { await viewModel.compareWithPrevious() }
                    }
                    .help("Compare the selected build with the next older one")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("Outcome", selection: $viewModel.outcomeFilter) {
                    Text("All").tag(Optional<BuildOutcome>.none)
                    ForEach(BuildOutcome.allCases) { outcome in
                        Text(outcome.displayName).tag(Optional(outcome))
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 110)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isIndexing {
                ProgressView("Indexing profile reports…")
                    .padding(8)
                    .background(.bar, in: Capsule())
                    .padding()
            }
        }
    }

    private var subtitle: String {
        guard viewModel.selectedProject != nil else { return "" }
        let count = viewModel.filteredBuilds.count
        return "\(count) local build\(count == 1 ? "" : "s")"
    }

    private func compareRole(for id: UUID) -> String? {
        if viewModel.compareBaselineID == id { return "A" }
        if viewModel.compareCandidateID == id { return "B" }
        return nil
    }

    private var buildSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedBuildID },
            set: { newValue in
                Task { await viewModel.selectBuild(newValue) }
            }
        )
    }
}

private struct BuildRow: View {
    let build: BuildRecord
    var role: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let role {
                    Text(role)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                }
                Text(build.requestedTasksLabel)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(DurationFormat.display(build.duration))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                StatusBadge(outcome: build.outcome)
                if build.hasLocalScan {
                    Text("Scan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                }
                Text(build.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let version = build.gradleVersion {
                    Text("Gradle \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
