import GradleLensCore
import SwiftUI

struct TimelineView: View {
    let tasks: [ProfileTask]
    var limit: Int = 12

    private var ranked: [ProfileTask] {
        Array(tasks.sorted { $0.duration > $1.duration }.prefix(limit))
    }

    private var total: TimeInterval {
        max(tasks.reduce(0) { $0 + $1.duration }, 0.000_1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            shareBar
            ForEach(ranked) { task in
                HStack(spacing: 10) {
                    Text(task.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.1))
                            Capsule()
                                .fill(task.result.barColor)
                                .frame(width: max(4, proxy.size.width * CGFloat(task.duration / total)))
                        }
                    }
                    .frame(width: 140, height: 8)
                    Text(DurationFormat.display(task.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(task.path), \(DurationFormat.display(task.duration)), \(task.result.displayName)")
            }
        }
    }

    private var shareBar: some View {
        let slices = ranked
        return GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(slices) { task in
                    Rectangle()
                        .fill(task.result.barColor)
                        .frame(width: max(2, proxy.size.width * CGFloat(task.duration / total)))
                        .help("\(task.path) · \(DurationFormat.display(task.duration))")
                }
            }
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("Task duration share of the top \(ranked.count) tasks")
    }
}
