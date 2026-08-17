import GradleLensCore
import SwiftUI

struct ContentView: View {
    @State private var viewModel: AppViewModel

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationSplitView {
            ProjectSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } content: {
            BuildListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
        } detail: {
            BuildDetailView(viewModel: viewModel)
        }
        .inspector(isPresented: $viewModel.inspectorVisible) {
            ProjectInspectorView(viewModel: viewModel)
                .inspectorColumnWidth(min: 240, ideal: 280, max: 380)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Reload projects, profile reports, git status, and the local cache")
                .disabled(viewModel.isLoading)

                Button {
                    viewModel.inspectorVisible.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Toggle git, structure, and cache inspector")
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: status) {
                        try? await Task.sleep(for: .seconds(3.5))
                        if viewModel.statusMessage == status {
                            viewModel.statusMessage = nil
                        }
                    }
            }
        }
        .frame(minWidth: 1060, minHeight: 640)
        .onReceive(NotificationCenter.default.publisher(for: .gradleLensOpenProject)) { _ in
            Task {
                if let url = await FolderPicker.pickFolder(message: "Choose a Gradle project root") {
                    await viewModel.openProject(at: url)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gradleLensScanFolder)) { _ in
            Task {
                if let url = await FolderPicker.pickFolder(message: "Scan this folder for Gradle projects", prompt: "Scan") {
                    await viewModel.scanFolder(at: url)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gradleLensRefresh)) { _ in
            Task { await viewModel.refresh() }
        }
        .task {
            await viewModel.bootstrap()
        }
    }
}
