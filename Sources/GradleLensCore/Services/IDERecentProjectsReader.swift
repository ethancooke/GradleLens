import Foundation

public struct IDERecentProject: Sendable, Hashable {
    public let path: String
    public let lastOpenedAt: Date?

    public init(path: String, lastOpenedAt: Date?) {
        self.path = path
        self.lastOpenedAt = lastOpenedAt
    }
}

public struct IDERecentProjectsReader: Sendable {
    public init() {}

    public func read(
        applicationSupport: URL = defaultApplicationSupport(),
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) -> [IDERecentProject] {
        let candidates = recentProjectFiles(under: applicationSupport)
        var seen: [String: IDERecentProject] = [:]
        for file in candidates {
            guard let xml = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for item in Self.parse(xml: xml, homeDirectory: homeDirectory) {
                if let existing = seen[item.path] {
                    let existingDate = existing.lastOpenedAt ?? .distantPast
                    let newDate = item.lastOpenedAt ?? .distantPast
                    if newDate > existingDate {
                        seen[item.path] = item
                    }
                } else {
                    seen[item.path] = item
                }
            }
        }
        return seen.values.sorted { lhs, rhs in
            (lhs.lastOpenedAt ?? .distantPast) > (rhs.lastOpenedAt ?? .distantPast)
        }
    }

    public static func defaultApplicationSupport() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    }

    func recentProjectFiles(under applicationSupport: URL) -> [URL] {
        var files: [URL] = []
        let roots = [
            applicationSupport.appendingPathComponent("Google", isDirectory: true),
            applicationSupport.appendingPathComponent("JetBrains", isDirectory: true),
        ]
        for root in roots {
            guard
                let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }
            for case let file as URL in enumerator {
                if file.lastPathComponent == "recentProjects.xml" {
                    files.append(file)
                }
            }
        }
        return files
    }

    public static func parse(xml: String, homeDirectory: URL) -> [IDERecentProject] {
        var results: [IDERecentProject] = []
        let home = homeDirectory.path
        var search = xml[...]

        while let entry = search.range(of: #"<entry key=""#) {
            let after = search[entry.upperBound...]
            guard let endQuote = after.firstIndex(of: "\"") else { break }
            let rawPath = String(after[..<endQuote])
            let valueChunk: String
            if let close = after.range(of: "</entry>") {
                valueChunk = String(after[..<close.upperBound])
                search = after[close.upperBound...]
            } else {
                valueChunk = String(after)
                search = after[endQuote...]
            }
            let opened = timestamp(in: valueChunk, keys: ["projectOpenTimestamp", "activationTimestamp"])
            results.append(
                IDERecentProject(
                    path: expand(rawPath, home: home),
                    lastOpenedAt: opened
                )
            )
        }

        if let recentPaths = xml.range(of: #"name="recentPaths""#) {
            let chunk = xml[recentPaths.lowerBound...]
            let limited = chunk.range(of: "</option>").map { chunk[..<$0.upperBound] } ?? chunk
            let optionRegex = try? NSRegularExpression(pattern: #"value="([^"]+)""#)
            let ns = NSRange(limited.startIndex..<limited.endIndex, in: limited)
            optionRegex?.enumerateMatches(in: String(limited), range: ns) { match, _, _ in
                guard let match, let range = Range(match.range(at: 1), in: limited) else { return }
                results.append(
                    IDERecentProject(
                        path: expand(String(limited[range]), home: home),
                        lastOpenedAt: nil
                    )
                )
            }
        }

        return results
    }

    private static func timestamp(in xml: String, keys: [String]) -> Date? {
        for key in keys {
            if let regex = try? NSRegularExpression(
                pattern: #"name="\#(key)"\s+value="(\d+)""#
            ) {
                let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
                if let match = regex.firstMatch(in: xml, range: range),
                   let valueRange = Range(match.range(at: 1), in: xml),
                   let millis = Double(xml[valueRange])
                {
                    return Date(timeIntervalSince1970: millis / 1000)
                }
            }
        }
        return nil
    }

    private static func expand(_ raw: String, home: String) -> String {
        raw.replacingOccurrences(of: "$USER_HOME$", with: home)
            .replacingOccurrences(of: "~", with: home)
    }
}
