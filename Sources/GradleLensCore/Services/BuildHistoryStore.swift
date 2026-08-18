import Foundation
import SQLite3

public actor BuildHistoryStore {
    private let connection: Connection

    public init(databaseURL: URL?) throws {
        let path: String
        if let databaseURL {
            let directory = databaseURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            path = databaseURL.path
        } else {
            path = ":memory:"
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw GradleLensError.database("Unable to open SQLite database at \(path)")
        }
        try Self.exec(handle, "PRAGMA foreign_keys = ON;")
        try Self.exec(handle, "PRAGMA journal_mode = WAL;")
        try Self.migrate(handle)
        connection = Connection(handle: handle)
    }

    public static func applicationDefault() throws -> BuildHistoryStore {
        try BuildHistoryStore(databaseURL: AppPaths.defaultDatabaseURL())
    }

    public static func inMemory() throws -> BuildHistoryStore {
        try BuildHistoryStore(databaseURL: nil)
    }

    private var db: OpaquePointer? { connection.handle }

    public func allProjects() throws -> [GradleProject] {
        let sql = """
            SELECT path, name, last_opened_at, last_indexed_at, source
            FROM projects
            ORDER BY last_opened_at DESC;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        var projects: [GradleProject] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            projects.append(project(from: statement))
        }
        return projects
    }

    public func project(id: String) throws -> GradleProject? {
        let sql = """
            SELECT path, name, last_opened_at, last_indexed_at, source
            FROM projects WHERE path = ? LIMIT 1;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return project(from: statement)
    }

    public func upsertProject(_ project: GradleProject) throws {
        let sql = """
            INSERT INTO projects (path, name, last_opened_at, last_indexed_at, source)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                name = excluded.name,
                last_opened_at = excluded.last_opened_at,
                last_indexed_at = excluded.last_indexed_at,
                source = excluded.source;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, project.rootPath)
        bind(statement, 2, project.name)
        bind(statement, 3, project.lastOpenedAt.timeIntervalSince1970)
        if let indexed = project.lastIndexedAt {
            bind(statement, 4, indexed.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        bind(statement, 5, project.source.rawValue)
        try stepDone(statement)
    }

    public func removeProject(id: String) throws {
        let statement = try prepare("DELETE FROM projects WHERE path = ?;")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id)
        try stepDone(statement)
    }

    public func upsertBuild(_ build: BuildRecord) throws {
        if let scanPath = build.scanPath, let existing = try record(scanPath: scanPath) {
            try replace(existingID: existing.id, with: build)
            return
        }
        if let profilePath = build.profilePath, let existing = try record(profilePath: profilePath) {
            try replace(existingID: existing.id, with: build)
            return
        }
        try insert(build)
    }

    public func containsProfile(path: String) throws -> Bool {
        try containsSource(path)
    }

    public func containsSource(_ path: String) throws -> Bool {
        let statement = try prepare(
            "SELECT 1 FROM builds WHERE profile_path = ? OR scan_path = ? LIMIT 1;"
        )
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, path)
        bind(statement, 2, path)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    public func record(profilePath: String) throws -> BuildRecord? {
        try firstBuild(where: "profile_path = ?", path: profilePath)
    }

    public func record(scanPath: String) throws -> BuildRecord? {
        try firstBuild(where: "scan_path = ?", path: scanPath)
    }

    public func build(id: UUID) throws -> BuildRecord? {
        let sql = """
            SELECT id, project_id, started_at, duration_seconds, outcome, requested_tasks,
                   gradle_version, profile_path, scan_path, git_branch, git_commit, imported_at
            FROM builds WHERE id = ? LIMIT 1;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id.uuidString)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return try build(from: statement)
    }

    public func builds(forProjectID projectID: String, matching query: BuildQuery = BuildQuery()) throws -> [BuildRecord] {
        var sql = """
            SELECT id, project_id, started_at, duration_seconds, outcome, requested_tasks,
                   gradle_version, profile_path, scan_path, git_branch, git_commit, imported_at
            FROM builds
            WHERE project_id = ?
            """
        if query.outcome != nil {
            sql += " AND outcome = ?"
        }
        if !query.search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sql += " AND (requested_tasks LIKE ? OR outcome LIKE ? OR IFNULL(profile_path, '') LIKE ?)"
        }
        sql += " ORDER BY started_at DESC LIMIT ?;"

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        bind(statement, index, projectID)
        index += 1
        if let outcome = query.outcome {
            bind(statement, index, outcome.rawValue)
            index += 1
        }
        let trimmed = query.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let like = "%\(trimmed)%"
            bind(statement, index, like)
            bind(statement, index + 1, like)
            bind(statement, index + 2, like)
            index += 3
        }
        sqlite3_bind_int(statement, index, Int32(query.limit))

        var records: [BuildRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(try build(from: statement))
        }
        return records
    }

    // MARK: - Private

    private static func migrate(_ db: OpaquePointer?) throws {
        try exec(
            db,
            """
            CREATE TABLE IF NOT EXISTS projects (
                path TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                last_opened_at REAL NOT NULL,
                last_indexed_at REAL,
                source TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS builds (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL REFERENCES projects(path) ON DELETE CASCADE,
                started_at REAL NOT NULL,
                duration_seconds REAL NOT NULL,
                outcome TEXT NOT NULL,
                requested_tasks TEXT NOT NULL,
                gradle_version TEXT,
                profile_path TEXT UNIQUE,
                scan_path TEXT UNIQUE,
                git_branch TEXT,
                git_commit TEXT,
                imported_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS builds_project_started
                ON builds(project_id, started_at DESC);
            """
        )
        try addColumnIfNeeded(db, table: "builds", column: "scan_path", definition: "TEXT")
        try exec(db, "CREATE UNIQUE INDEX IF NOT EXISTS builds_scan_path ON builds(scan_path) WHERE scan_path IS NOT NULL;")
    }

    private func firstBuild(where clause: String, path: String) throws -> BuildRecord? {
        let sql = """
            SELECT id, project_id, started_at, duration_seconds, outcome, requested_tasks,
                   gradle_version, profile_path, scan_path, git_branch, git_commit, imported_at
            FROM builds WHERE \(clause) LIMIT 1;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, path)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return try build(from: statement)
    }

    private func insert(_ build: BuildRecord) throws {
        let sql = """
            INSERT INTO builds (
                id, project_id, started_at, duration_seconds, outcome, requested_tasks,
                gradle_version, profile_path, scan_path, git_branch, git_commit, imported_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bindBuild(statement, build, id: build.id)
        try stepDone(statement)
    }

    private func replace(existingID: UUID, with build: BuildRecord) throws {
        let sql = """
            UPDATE builds SET
                project_id = ?, started_at = ?, duration_seconds = ?, outcome = ?,
                requested_tasks = ?, gradle_version = ?, profile_path = ?, scan_path = ?,
                git_branch = ?, git_commit = ?, imported_at = ?
            WHERE id = ?;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let tasksJSON = String(decoding: try JSONEncoder().encode(build.requestedTasks), as: UTF8.self)
        bind(statement, 1, build.projectID)
        bind(statement, 2, build.startedAt.timeIntervalSince1970)
        bind(statement, 3, build.duration)
        bind(statement, 4, build.outcome.rawValue)
        bind(statement, 5, tasksJSON)
        bindOptional(statement, 6, build.gradleVersion)
        bindOptional(statement, 7, build.profilePath)
        bindOptional(statement, 8, build.scanPath)
        bindOptional(statement, 9, build.gitBranch)
        bindOptional(statement, 10, build.gitCommit)
        bind(statement, 11, build.importedAt.timeIntervalSince1970)
        bind(statement, 12, existingID.uuidString)
        try stepDone(statement)
    }

    private func bindBuild(_ statement: OpaquePointer?, _ build: BuildRecord, id: UUID) {
        let tasksJSON = String(decoding: (try? JSONEncoder().encode(build.requestedTasks)) ?? Data("[]".utf8), as: UTF8.self)
        bind(statement, 1, id.uuidString)
        bind(statement, 2, build.projectID)
        bind(statement, 3, build.startedAt.timeIntervalSince1970)
        bind(statement, 4, build.duration)
        bind(statement, 5, build.outcome.rawValue)
        bind(statement, 6, tasksJSON)
        bindOptional(statement, 7, build.gradleVersion)
        bindOptional(statement, 8, build.profilePath)
        bindOptional(statement, 9, build.scanPath)
        bindOptional(statement, 10, build.gitBranch)
        bindOptional(statement, 11, build.gitCommit)
        bind(statement, 12, build.importedAt.timeIntervalSince1970)
    }

    private static func addColumnIfNeeded(
        _ db: OpaquePointer?,
        table: String,
        column: String,
        definition: String
    ) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &statement, nil) == SQLITE_OK else {
            return
        }
        var exists = false
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1), String(cString: name) == column {
                exists = true
                break
            }
        }
        if !exists {
            try exec(db, "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
        }
    }

    private func project(from statement: OpaquePointer?) -> GradleProject {
        let path = columnText(statement, 0) ?? ""
        let name = columnText(statement, 1) ?? URL(fileURLWithPath: path).lastPathComponent
        let opened = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let indexed: Date? = sqlite3_column_type(statement, 3) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
        let source = ProjectSource(rawValue: columnText(statement, 4) ?? "") ?? .manual
        return GradleProject(
            rootPath: path,
            name: name,
            lastOpenedAt: opened,
            lastIndexedAt: indexed,
            source: source
        )
    }

    private func build(from statement: OpaquePointer?) throws -> BuildRecord {
        let idString = columnText(statement, 0) ?? UUID().uuidString
        let tasksJSON = columnText(statement, 5) ?? "[]"
        let tasks = (try? JSONDecoder().decode([String].self, from: Data(tasksJSON.utf8))) ?? []
        return BuildRecord(
            id: UUID(uuidString: idString) ?? UUID(),
            projectID: columnText(statement, 1) ?? "",
            startedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
            duration: sqlite3_column_double(statement, 3),
            outcome: BuildOutcome(rawValue: columnText(statement, 4) ?? "") ?? .unknown,
            requestedTasks: tasks,
            gradleVersion: columnText(statement, 6),
            profilePath: columnText(statement, 7),
            scanPath: columnText(statement, 8),
            gitBranch: columnText(statement, 9),
            gitCommit: columnText(statement, 10),
            importedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 11))
        )
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw GradleLensError.database(lastError())
        }
        return statement
    }

    private static func exec(_ db: OpaquePointer?, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &error)
        if let error {
            let message = String(cString: error)
            sqlite3_free(error)
            if status != SQLITE_OK {
                throw GradleLensError.database(message)
            }
        } else if status != SQLITE_OK {
            throw GradleLensError.database(Self.errorMessage(from: db))
        }
    }

    private static func errorMessage(from db: OpaquePointer?) -> String {
        if let db, let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "Unknown SQLite error"
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE else {
            throw GradleLensError.database(lastError())
        }
    }

    private func lastError() -> String {
        Self.errorMessage(from: db)
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index)
        else { return nil }
        return String(cString: pointer)
    }

    private func bind(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func bindOptional(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            bind(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ statement: OpaquePointer?, _ index: Int32, _ value: Double) {
        sqlite3_bind_double(statement, index, value)
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private final class Connection: @unchecked Sendable {
        let handle: OpaquePointer?

        init(handle: OpaquePointer?) {
            self.handle = handle
        }

        deinit {
            sqlite3_close(handle)
        }
    }
}
