import GradleLensCore
import SwiftUI

struct PhaseBreakdownView: View {
    let summary: ProfileSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(summary.phases) { phase in
                HStack(spacing: 10) {
                    Text(phase.name)
                        .frame(width: 170, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                            Capsule()
                                .fill(Color.accentColor.opacity(0.85))
                                .frame(width: barWidth(for: phase.duration, in: proxy.size.width))
                        }
                    }
                    .frame(height: 8)
                    Text(DurationFormat.display(phase.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(phase.name), \(DurationFormat.display(phase.duration))")
            }
        }
    }

    private func barWidth(for duration: TimeInterval, in totalWidth: CGFloat) -> CGFloat {
        let maxDuration = max(summary.totalBuildTime, summary.phases.map(\.duration).max() ?? 0)
        guard maxDuration > 0 else { return 0 }
        return max(4, totalWidth * CGFloat(duration / maxDuration))
    }
}
