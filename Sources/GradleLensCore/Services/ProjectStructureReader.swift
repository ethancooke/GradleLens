import Foundation

public struct ProjectStructureReader: Sendable {
    public init() {}

    public func read(projectRoot: URL) throws -> ProjectStructure {
        let settingsURL = GradleProjectDetector.settingsFile(at: projectRoot)
        let settingsContents = settingsURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let rootName = Self.rootProjectName(in: settingsContents) ?? projectRoot.lastPathComponent
        let modulePaths = Self.includedModulePaths(in: settingsContents)
        let includedBuilds = Self.includedBuilds(in: settingsContents)

        var modules: [GradleModule] = []
        let rootTasks = inferredTasks(in: GradleProjectDetector.buildFile(at: projectRoot))
        if !modulePaths.isEmpty {
            modules.append(GradleModule(path: ":", directory: ".", inferredTasks: rootTasks))
        }
        let paths = modulePaths.isEmpty ? [":"] : modulePaths
        if modulePaths.isEmpty {
            modules = [GradleModule(path: ":", directory: ".", inferredTasks: rootTasks)]
        } else {
            for path in paths {
                let directory = Self.directory(forModulePath: path)
                let buildFile = GradleProjectDetector.buildFile(
                    at: projectRoot.appendingPathComponent(directory)
                )
                modules.append(
                    GradleModule(
                        path: path.hasPrefix(":") ? path : ":\(path)",
                        directory: directory,
                        inferredTasks: inferredTasks(in: buildFile)
                    )
                )
            }
        }

        return ProjectStructure(
            rootName: rootName,
            modules: modules,
            includedBuilds: includedBuilds,
            gradleVersion: GradleProjectDetector.gradleVersion(at: projectRoot),
            settingsFileName: settingsURL?.lastPathComponent
        )
    }

    public static func rootProjectName(in source: String) -> String? {
        let stripped = stripComments(source)
        guard
            let regex = try? NSRegularExpression(
                pattern: #"rootProject\.name\s*=\s*["']([^"']+)["']"#
            )
        else { return nil }
        let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
        guard let match = regex.firstMatch(in: stripped, range: range),
              let nameRange = Range(match.range(at: 1), in: stripped)
        else { return nil }
        return String(stripped[nameRange])
    }

    public static func includedModulePaths(in source: String) -> [String] {
        quotedArguments(in: stripComments(source), keyword: "include", excluding: "includeBuild")
            .map { $0.hasPrefix(":") ? $0 : ":\($0)" }
    }

    public static func includedBuilds(in source: String) -> [String] {
        quotedArguments(in: stripComments(source), keyword: "includeBuild", excluding: nil)
    }

    public static func directory(forModulePath path: String) -> String {
        let trimmed = path.hasPrefix(":") ? String(path.dropFirst()) : path
        return trimmed.replacingOccurrences(of: ":", with: "/")
    }

    static func stripComments(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        var inBlock = false
        var inLine = false
        var inString: Character?

        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            let peek = next < source.endIndex ? source[next] : nil

            if let quote = inString {
                result.append(character)
                if character == "\\" && next < source.endIndex {
                    result.append(source[next])
                    index = source.index(after: next)
                    continue
                }
                if character == quote {
                    inString = nil
                }
                index = next
                continue
            }

            if inLine {
                if character == "\n" {
                    inLine = false
                    result.append(character)
                }
                index = next
                continue
            }

            if inBlock {
                if character == "*" && peek == "/" {
                    inBlock = false
                    index = source.index(after: next)
                    continue
                }
                index = next
                continue
            }

            if character == "/" && peek == "/" {
                inLine = true
                index = source.index(after: next)
                continue
            }
            if character == "/" && peek == "*" {
                inBlock = true
                index = source.index(after: next)
                continue
            }
            if character == "\"" || character == "'" {
                inString = character
                result.append(character)
                index = next
                continue
            }

            result.append(character)
            index = next
        }
        return result
    }

    private static func quotedArguments(
        in source: String,
        keyword: String,
        excluding: String?
    ) -> [String] {
        var results: [String] = []
        var search = source[...]
        while let range = search.range(of: keyword) {
            let prefix = search[..<range.lowerBound]
            let precededByIdent = prefix.last.map { $0.isLetter || $0.isNumber || $0 == "_" } ?? false
            let afterKeyword = search[range.upperBound...]
            let isExcluded: Bool = {
                guard let excluding, excluding.hasPrefix(keyword) else { return false }
                let extra = excluding.dropFirst(keyword.count)
                return afterKeyword.hasPrefix(extra)
            }()

            if precededByIdent || isExcluded {
                search = afterKeyword
                continue
            }

            let remainder = String(afterKeyword)
            guard let open = remainder.firstIndex(where: { !$0.isWhitespace }) else { break }
            var collected: [String] = []
            if remainder[open] == "(" {
                if let close = findMatchingParen(in: remainder, opening: open) {
                    collected = extractQuotedStrings(from: String(remainder[open...close]))
                    search = remainder[remainder.index(after: close)...]
                } else {
                    collected = extractQuotedStrings(from: remainder)
                    break
                }
            } else {
                // Groovy `include 'app', 'lib'`
                let lineEnd = remainder[open...].firstIndex(of: "\n") ?? remainder.endIndex
                collected = extractQuotedStrings(from: String(remainder[open..<lineEnd]))
                search = remainder[lineEnd...]
            }
            results.append(contentsOf: collected)
        }
        return results
    }

    private static func findMatchingParen(in source: String, opening: String.Index) -> String.Index? {
        var depth = 0
        var inString: Character?
        var index = opening
        while index < source.endIndex {
            let character = source[index]
            if let quote = inString {
                if character == "\\" {
                    index = source.index(after: index)
                    if index < source.endIndex {
                        index = source.index(after: index)
                    }
                    continue
                }
                if character == quote { inString = nil }
            } else if character == "\"" || character == "'" {
                inString = character
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = source.index(after: index)
        }
        return nil
    }

    static func extractQuotedStrings(from source: String) -> [String] {
        var results: [String] = []
        var index = source.startIndex
        while index < source.endIndex {
            let character = source[index]
            if character == "\"" || character == "'" {
                let quote = character
                var next = source.index(after: index)
                var value = ""
                while next < source.endIndex {
                    let inner = source[next]
                    if inner == "\\" {
                        let escaped = source.index(after: next)
                        if escaped < source.endIndex {
                            value.append(source[escaped])
                            next = source.index(after: escaped)
                            continue
                        }
                    }
                    if inner == quote { break }
                    value.append(inner)
                    next = source.index(after: next)
                }
                results.append(value)
                index = next < source.endIndex ? source.index(after: next) : next
                continue
            }
            index = source.index(after: index)
        }
        return results
    }

    private func inferredTasks(in buildFile: URL?) -> [String] {
        guard let buildFile, let contents = try? String(contentsOf: buildFile, encoding: .utf8) else {
            return []
        }
        return Self.inferredTasks(inSource: contents)
    }

    public static func inferredTasks(inSource source: String) -> [String] {
        let stripped = stripComments(source)
        var tasks = Set<String>()

        if let named = try? NSRegularExpression(
            pattern: #"tasks\.register(?:<[^>]+>)?\(\s*["']([^"']+)["']"#
        ) {
            let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            named.enumerateMatches(in: stripped, range: range) { match, _, _ in
                guard let match, let taskRange = Range(match.range(at: 1), in: stripped) else { return }
                tasks.insert(String(stripped[taskRange]))
            }
        }

        if let groovy = try? NSRegularExpression(pattern: #"\btask\s+["']([^"']+)["']"#) {
            let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            groovy.enumerateMatches(in: stripped, range: range) { match, _, _ in
                guard let match, let taskRange = Range(match.range(at: 1), in: stripped) else { return }
                tasks.insert(String(stripped[taskRange]))
            }
        }

        if let groovyIdent = try? NSRegularExpression(pattern: #"\btask\s+([A-Za-z_][A-Za-z0-9_]*)"#) {
            let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            groovyIdent.enumerateMatches(in: stripped, range: range) { match, _, _ in
                guard let match, let taskRange = Range(match.range(at: 1), in: stripped) else { return }
                tasks.insert(String(stripped[taskRange]))
            }
        }

        for plugin in pluginIDs(in: stripped) {
            tasks.formUnion(Self.tasksImplied(byPlugin: plugin))
        }

        return tasks.sorted()
    }

    private static func pluginIDs(in source: String) -> [String] {
        var ids: [String] = []
        if let quoted = try? NSRegularExpression(pattern: #"\bid\s*\(?\s*["']([^"']+)["']"#) {
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            quoted.enumerateMatches(in: source, range: range) { match, _, _ in
                guard let match, let idRange = Range(match.range(at: 1), in: source) else { return }
                ids.append(String(source[idRange]))
            }
        }
        if let alias = try? NSRegularExpression(pattern: #"\balias\s*\(\s*([^)]+)\)"#) {
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            alias.enumerateMatches(in: source, range: range) { match, _, _ in
                guard let match, let idRange = Range(match.range(at: 1), in: source) else { return }
                ids.append(String(source[idRange]))
            }
        }
        return ids
    }

    private static func tasksImplied(byPlugin plugin: String) -> [String] {
        let id = plugin.lowercased()
        if id == "java" || id == "java-library" || id.contains("java") && id.contains("library") {
            return ["compileJava", "test", "jar", "classes"]
        }
        if id.contains("kotlin.jvm") || id.hasSuffix("kotlin.jvm") || id.contains("jetbrains.kotlin.jvm") {
            return ["compileKotlin", "compileTestKotlin", "test"]
        }
        if id.contains("android.application") {
            return ["assembleDebug", "assembleRelease", "bundleDebug", "lint"]
        }
        if id.contains("android.library") {
            return ["assembleDebug", "assembleRelease", "lint"]
        }
        if id == "application" || id.contains("application") && !id.contains("android") {
            return ["run"]
        }
        return []
    }
}
