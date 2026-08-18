import Foundation

public struct LocalScanParser: Sendable {
    public init() {}

    public func parse(fileAt url: URL) throws -> LocalScan {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GradleLensError.profileParseFailed("Unable to read \(url.path): \(error.localizedDescription)")
        }
        return try parse(data: data, sourcePath: url.path)
    }

    public func parse(data: Data, sourcePath: String) throws -> LocalScan {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: raw) ?? basic.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(raw)")
        }
        let dto: ScanDTO
        do {
            dto = try decoder.decode(ScanDTO.self, from: data)
        } catch {
            throw GradleLensError.profileParseFailed("Invalid scan JSON: \(error.localizedDescription)")
        }
        return LocalScan(
            sourcePath: sourcePath,
            schemaVersion: dto.schemaVersion,
            startedAt: dto.startedAt,
            finishedAt: dto.finishedAt,
            duration: dto.durationSeconds,
            outcome: BuildOutcome(rawValue: dto.outcome) ?? .unknown,
            requestedTasks: dto.requestedTasks ?? [],
            excludedTasks: dto.excludedTasks ?? [],
            gradleVersion: dto.gradleVersion,
            configurationCacheRequested: dto.configurationCacheRequested,
            git: dto.git.map { LocalScanGit(branch: $0.branch, commit: $0.commit, dirty: $0.dirty) },
            taskExecution: dto.phases?.taskExecution,
            tasks: (dto.tasks ?? []).map { task in
                ProfileTask(
                    path: task.path,
                    duration: task.durationSeconds,
                    result: TaskResult(rawValue: task.result) ?? TaskResult.parse(task.result),
                    rawResult: task.skipMessage ?? task.result,
                    startOffset: task.startOffsetSeconds
                )
            }
        )
    }
}

private struct ScanDTO: Decodable {
    let schemaVersion: Int
    let startedAt: Date
    let finishedAt: Date?
    let durationSeconds: TimeInterval
    let outcome: String
    let requestedTasks: [String]?
    let excludedTasks: [String]?
    let gradleVersion: String?
    let configurationCacheRequested: Bool?
    let git: GitDTO?
    let phases: PhasesDTO?
    let tasks: [TaskDTO]?
}

private struct GitDTO: Decodable {
    let branch: String?
    let commit: String?
    let dirty: Bool?
}

private struct PhasesDTO: Decodable {
    let total: TimeInterval?
    let taskExecution: TimeInterval?
}

private struct TaskDTO: Decodable {
    let path: String
    let durationSeconds: TimeInterval
    let startOffsetSeconds: TimeInterval?
    let result: String
    let skipMessage: String?
}
