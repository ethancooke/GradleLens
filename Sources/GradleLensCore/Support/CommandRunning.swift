import Foundation

public struct CommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var succeeded: Bool { exitCode == 0 }
}

public protocol CommandRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL?,
        environment: [String: String]
    ) async throws -> CommandResult
}

public struct SystemCommandRunner: CommandRunning {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL?,
        environment: [String: String]
    ) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.runSync(
                executable: executable,
                arguments: arguments,
                currentDirectory: currentDirectory,
                environment: environment
            )
        }.value
    }

    private static func runSync(
        executable: String,
        arguments: [String],
        currentDirectory: URL?,
        environment: [String: String]
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        if !environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}
