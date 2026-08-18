import GradleLensCore
import SwiftUI

struct CommandSeriesList: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        List(selection: commandSelection) {
            ForEach(viewModel.commandSeries) { series in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(series.key)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text("\(series.runCount) run\(series.runCount == 1 ? "" : "s")")
                            Text("median \(DurationFormat.display(series.medianDuration))")
                            if series.failureRate > 0 {
                                Text(series.failureRate.formatted(.percent.precision(.fractionLength(0))) + " failed")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if series.recentDurations.count >= 2 {
                        DurationSparkline(durations: series.recentDurations)
                    }
                }
                .tag(series.key)
                .padding(.vertical, 3)
            }
        }
        .navigationTitle(viewModel.selectedProject?.name ?? "Trends")
        .navigationSubtitle("\(viewModel.commandSeries.count) command\(viewModel.commandSeries.count == 1 ? "" : "s")")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Builds") {
                    viewModel.showingTrends = false
                }
            }
        }
    }

    private var commandSelection: Binding<String?> {
        Binding(
            get: { viewModel.selectedCommandOrDefault },
            set: { viewModel.selectCommand($0) }
        )
    }
}
