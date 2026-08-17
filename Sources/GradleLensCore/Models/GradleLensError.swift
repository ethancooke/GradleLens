import Foundation

public enum GradleLensError: Error, Sendable, Equatable, LocalizedError {
    case notAGradleProject(String)
    case profileParseFailed(String)
    case database(String)
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .notAGradleProject(let path):
            "Not a Gradle project: \(path)"
        case .profileParseFailed(let reason):
            "Could not parse profile report: \(reason)"
        case .database(let reason):
            "Local history database error: \(reason)"
        case .io(let reason):
            reason
        }
    }
}
