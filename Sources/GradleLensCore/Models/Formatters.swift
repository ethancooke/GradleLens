import Foundation

public enum DurationFormat: Sendable {
    /// Parses Gradle `TimeFormatting.formatDurationVeryTerse` output (`12.345s`, `1m12.34s`, `1h2m3.00s`).
    public static func parseGradle(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var remaining = trimmed
        var total: TimeInterval = 0

        if let range = remaining.range(of: #"(\d+)\s*h"#, options: .regularExpression) {
            let digits = remaining[range].filter(\.isNumber)
            if let hours = Double(digits) {
                total += hours * 3600
            }
            remaining.removeSubrange(range)
        }

        if let range = remaining.range(of: #"(\d+)\s*m(?!s)"#, options: .regularExpression) {
            let digits = remaining[range].filter(\.isNumber)
            if let minutes = Double(digits) {
                total += minutes * 60
            }
            remaining.removeSubrange(range)
        }

        if let range = remaining.range(of: #"(\d+(?:\.\d+)?)\s*ms"#, options: .regularExpression) {
            let number = remaining[range].replacingOccurrences(of: "ms", with: "").trimmingCharacters(in: .whitespaces)
            if let millis = Double(number) {
                total += millis / 1000
            }
            remaining.removeSubrange(range)
        }

        if let range = remaining.range(of: #"(\d+(?:\.\d+)?)\s*s"#, options: .regularExpression) {
            let number = remaining[range].replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)
            if let seconds = Double(number) {
                total += seconds
            }
            remaining.removeSubrange(range)
        }

        if total == 0, let value = Double(trimmed) {
            return value
        }

        let leftovers = remaining.trimmingCharacters(in: .whitespaces)
        if total == 0 && !leftovers.isEmpty {
            return nil
        }
        return total
    }

    public static func display(_ interval: TimeInterval) -> String {
        if interval.isNaN || interval.isInfinite { return "—" }
        let absValue = abs(interval)
        if absValue < 0.001 { return "0ms" }
        if absValue < 1 {
            return "\(Int((absValue * 1000).rounded()))ms"
        }
        if absValue < 60 {
            return String(format: "%.2fs", absValue)
        }
        let minutes = Int(absValue) / 60
        let seconds = absValue.truncatingRemainder(dividingBy: 60)
        if minutes < 60 {
            return String(format: "%dm %04.1fs", minutes, seconds)
        }
        let hours = minutes / 60
        let remainMinutes = minutes % 60
        return String(format: "%dh %dm %04.1fs", hours, remainMinutes, seconds)
    }
}

public enum ByteFormat: Sendable {
    public static func display(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

public enum PathFormat: Sendable {
    public static func abbreviatingHome(_ path: String, home: String = NSHomeDirectory()) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
