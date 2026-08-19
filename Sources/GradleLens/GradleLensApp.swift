import SwiftUI

@main
struct GradleLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("GradleLens") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Project…") {
                    NotificationCenter.default.post(name: .gradleLensOpenProject, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Scan Folder…") {
                    NotificationCenter.default.post(name: .gradleLensScanFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .gradleLensRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            CaptureSettingsView(viewModel: viewModel)
        }
    }
}

extension Notification.Name {
    static let gradleLensOpenProject = Notification.Name("GradleLens.openProject")
    static let gradleLensScanFolder = Notification.Name("GradleLens.scanFolder")
    static let gradleLensRefresh = Notification.Name("GradleLens.refresh")
}
