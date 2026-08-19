import GradleLensCore
import SwiftUI

struct ProjectInspectorView: View {
    var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gitSection
                structureSection
                cacheSection
                captureSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var gitSection: some View {
        GroupBox("Git") {
            if let git = viewModel.gitContext, git.isRepository {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Branch", value: git.branch ?? "—")
                    LabeledContent("HEAD", value: git.shortHead ?? "—")
                    LabeledContent("Working tree", value: git.isDirty ? "Dirty (\(git.dirtyFileCount))" : "Clean")
                    if !git.recentCommits.isEmpty {
                        Divider()
                        Text("Recent commits")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(git.recentCommits) { commit in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(commit.subject)
                                    .lineLimit(2)
                                Text("\(commit.shortSHA) · \(commit.author)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                Text("Not a git repository.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var structureSection: some View {
        GroupBox("Project structure") {
            if let structure = viewModel.projectStructure {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Root", value: structure.rootName)
                    if let version = structure.gradleVersion {
                        LabeledContent("Wrapper", value: "Gradle \(version)")
                    }
                    if let settings = structure.settingsFileName {
                        LabeledContent("Settings", value: settings)
                    }
                    Divider()
                    Text("Modules (\(structure.modules.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(structure.modules) { module in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.path)
                                .font(.system(.body, design: .monospaced))
                            if !module.inferredTasks.isEmpty {
                                Text(module.inferredTasks.prefix(6).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    if !structure.includedBuilds.isEmpty {
                        Divider()
                        Text("Included builds")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(structure.includedBuilds, id: \.self) { build in
                            Text(build)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            } else {
                Text("Open a project to inspect modules and key tasks.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cacheSection: some View {
        GroupBox("Build cache") {
            if let cache = viewModel.cacheOverview {
                CacheOverviewView(overview: cache)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var captureSection: some View {
        GroupBox("Richer capture") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    "Record extra Gradle details",
                    isOn: Binding(
                        get: { viewModel.isRicherCaptureEnabled },
                        set: { viewModel.setRicherCaptureEnabled($0) }
                    )
                )
                Text("Optional. Improves pass/fail and task timing. Change this anytime in Settings. The app works from --profile reports without it.")
                    .foregroundStyle(.secondary)
                if let status = viewModel.captureStatus, status.installed {
                    Text(PathFormat.abbreviatingHome(status.path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
