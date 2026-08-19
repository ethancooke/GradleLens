import GradleLensCore
import SwiftUI

struct CaptureOnboardingView: View {
    var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optional: richer Gradle capture")
                .font(.title2.weight(.semibold))
            Text("GradleLens already works. It reads the --profile reports Gradle writes on this Mac.")
            Text("If you turn this on, GradleLens places a small helper in ~/.gradle/init.d. After that, your own Gradle builds also write a local report with real pass/fail, task start times, and the git branch at that moment. Nothing is uploaded.")
            Text("You can change this later in Settings.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Not now") {
                    viewModel.dismissCaptureOnboarding()
                }
                Spacer()
                Button("Turn on") {
                    viewModel.setRicherCaptureEnabled(true)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

struct CaptureSettingsView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Richer Gradle capture",
                    isOn: Binding(
                        get: { viewModel.isRicherCaptureEnabled },
                        set: { viewModel.setRicherCaptureEnabled($0) }
                    )
                )
                Text("When on, a helper in ~/.gradle/init.d records extra pass/fail and timing on disk during your Gradle builds. GradleLens works without this. Nothing is uploaded.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let status = viewModel.captureStatus, status.installed {
                    LabeledContent("Helper") {
                        Text(PathFormat.abbreviatingHome(status.path))
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    if !status.matchesBundled {
                        Button("Update helper to this app version") {
                            viewModel.setRicherCaptureEnabled(true)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 180)
        .onAppear { viewModel.refreshCaptureStatus() }
        .padding()
    }
}
