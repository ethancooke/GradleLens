import Foundation

public actor GitService {
    private let runner: any CommandRunning
    private let gitExecutable: String

    public init(runner: any CommandRunning = SystemCommandRunner(), gitExecutable: String = "/usr/bin/git") {
        self.runner = runner
        self.gitExecutable = gitExecutable
    }

    public func context(for directory: URL, commitLimit: Int = 8) async -> GitContext {
        let inside = try? await git(["rev-parse", "--is-inside-work-tree"], cwd: directory)
        guard let inside, inside.succeeded, inside.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        else {
            return .notARepository
        }

        async let branchResult = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd: directory)
        async let headResult = git(["rev-parse", "HEAD"], cwd: directory)
        async let statusResult = git(["status", "--porcelain"], cwd: directory)
        async let logResult = git(
            ["log", "-\(commitLimit)", "--format=%H%x09%an%x09%aI%x09%s"],
            cwd: directory
        )

        let branch = (try? await branchResult)?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = (try? await headResult)?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = (try? await statusResult)?.stdout ?? ""
        let dirtyLines = status.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let commits = Self.parseLog((try? await logResult)?.stdout ?? "")

        return GitContext(
            isRepository: true,
            branch: branch == "" ? nil : branch,
            headSHA: head == "" ? nil : head,
            isDirty: !dirtyLines.isEmpty,
            dirtyFileCount: dirtyLines.count,
            recentCommits: commits
        )
    }

    private func git(_ arguments: [String], cwd: URL) async throws -> CommandResult {
        try await runner.run(
            executable: gitExecutable,
            arguments: arguments,
            currentDirectory: cwd,
            environment: [
                "GIT_TERMINAL_PROMPT": "0",
                "GIT_OPTIONAL_LOCKS": "0",
                "GCM_INTERACTIVE": "never",
            ]
        )
    }

    nonisolated static func parseLog(_ stdout: String) -> [GitCommit] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        return stdout.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard parts.count == 4 else { return nil }
            let dateString = String(parts[2])
            let date = formatter.date(from: dateString) ?? fallback.date(from: dateString) ?? .distantPast
            return GitCommit(
                sha: String(parts[0]),
                author: String(parts[1]),
                date: date,
                subject: String(parts[3])
            )
        }
    }
}
