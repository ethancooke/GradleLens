import GradleLensCore
import SwiftUI

struct StatusBadge: View {
    let outcome: BuildOutcome

    var body: some View {
        Text(outcome.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(outcome.displayName)
    }

    private var color: Color {
        switch outcome {
        case .succeeded: .green
        case .failed: .red
        case .unknown: .secondary
        }
    }
}

struct TaskResultBadge: View {
    let result: TaskResult

    var body: some View {
        Text(result.displayName)
            .font(.caption.monospaced())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch result {
        case .executed: .accentColor
        case .fromCache: .teal
        case .upToDate: .secondary
        case .skipped, .noWork: .orange
        case .failed: .red
        case .unknown: .secondary
        }
    }
}

extension TaskResult {
    var barColor: Color {
        switch self {
        case .executed: .accentColor
        case .fromCache: .teal
        case .upToDate: Color.secondary.opacity(0.7)
        case .skipped, .noWork: .orange
        case .failed: .red
        case .unknown: .gray
        }
    }
}
