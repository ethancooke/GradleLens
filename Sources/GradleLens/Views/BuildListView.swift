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
                    title: "No local profile reports",
                    message: """
                    GradleLens reads existing --profile HTML reports from build/reports/profile.

                    ./gradlew --profile <tasks>
                    """
                )
            } else {
                List(selection: buildSelection) {
                    ForEach(viewModel.filteredBuilds) { build in
                        BuildRow(build: build)
                            .tag(build.id)
                    }
                }
            }
        }
        .navigationTitle(viewModel.selectedProject?.name ?? "Builds")
        .navigationSubtitle(subtitle)
        .searchable(text: $viewModel.searchText, prompt: "Filter builds")
        .toolbar {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
