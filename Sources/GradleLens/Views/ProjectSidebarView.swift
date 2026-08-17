import GradleLensCore
import SwiftUI

struct ProjectSidebarView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List(selection: projectSelection) {
            Section("Projects") {
                if viewModel.projects.isEmpty {
                    Text("No projects yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.projects) { project in
                    ProjectRow(project: project, isMissing: viewModel.selectedProjectID == project.id && viewModel.projectMissingFromDisk)
                        .tag(project.id)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                WorkspaceOpener.reveal(project.rootURL)
                            }
                            Divider()
                            Button("Remove from List", role: .destructive) {
                                Task { await viewModel.removeProject(project.id) }
                            }
                        }
                }
            }

            Section("Local build cache") {
                CacheSummaryRow(overview: viewModel.cacheOverview)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("GradleLens")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    Task { await openProject() }
                } label: {
                    Label("Open", systemImage: "folder.badge.plus")
                }
                .help("Open a Gradle project")

                Button {
                    Task { await scanFolder() }
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .help("Scan a folder for Gradle projects")

                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    private var projectSelection: Binding<String?> {
        Binding(
            get: { viewModel.selectedProjectID },
            set: { newValue in
                Task { await viewModel.selectProject(newValue) }
            }
        )
    }

    private func openProject() async {
        if let url = await FolderPicker.pickFolder(message: "Choose a Gradle project root") {
            await viewModel.openProject(at: url)
        }
    }

    private func scanFolder() async {
        if let url = await FolderPicker.pickFolder(message: "Scan this folder for Gradle projects", prompt: "Scan") {
            await viewModel.scanFolder(at: url)
        }
    }
}

private struct ProjectRow: View {
    let project: GradleProject
    let isMissing: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                Text(PathFormat.abbreviatingHome(project.rootPath))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } icon: {
            Image(systemName: isMissing ? "exclamationmark.folder" : "hammer.fill")
                .foregroundStyle(isMissing ? .orange : .accentColor)
        }
    }
}

private struct CacheSummaryRow: View {
    let overview: BuildCacheOverview?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let overview, overview.exists {
                LabeledContent("Entries", value: overview.entryCount.formatted())
                LabeledContent("Size", value: ByteFormat.display(overview.totalBytes))
                if let newest = overview.newestEntry {
                    LabeledContent("Updated", value: newest.formatted(date: .abbreviated, time: .shortened))
                }
            } else {
                Text("No cache at ~/.gradle/caches/build-cache-1")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .font(.caption)
    }
}
