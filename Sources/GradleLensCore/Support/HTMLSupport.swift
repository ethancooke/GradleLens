import Foundation

enum HTMLSupport {
    static func unescape(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    static func slice(_ source: String, from start: String, to end: String) -> String? {
        guard let startRange = source.range(of: start, options: .caseInsensitive) else { return nil }
        let rest = source[startRange.upperBound...]
        guard let endRange = rest.range(of: end, options: .caseInsensitive) else { return nil }
        return String(rest[..<endRange.lowerBound])
    }

    static func tables(in html: String) -> [String] {
        var result: [String] = []
        var search = html[...]
        while let start = search.range(of: "<table", options: .caseInsensitive) {
            let fromStart = search[start.lowerBound...]
            guard let end = fromStart.range(of: "</table>", options: .caseInsensitive) else { break }
            result.append(String(fromStart[..<end.upperBound]))
            search = fromStart[end.upperBound...]
        }
        return result
    }

    static func rows(in tableHTML: String) -> [[String]] {
        var result: [[String]] = []
        var search = tableHTML[...]
        while let start = search.range(of: "<tr", options: .caseInsensitive) {
            let fromStart = search[start.lowerBound...]
            guard let end = fromStart.range(of: "</tr>", options: .caseInsensitive) else { break }
            let row = String(fromStart[..<end.upperBound])
            let cells = cells(in: row, tag: "td")
            if !cells.isEmpty {
                result.append(cells)
            }
            search = fromStart[end.upperBound...]
        }
        return result
    }

    static func cells(in rowHTML: String, tag: String) -> [String] {
        var result: [String] = []
        var search = rowHTML[...]
        let open = "<\(tag)"
        let close = "</\(tag)>"
        while let start = search.range(of: open, options: .caseInsensitive) {
            let fromStart = search[start.lowerBound...]
            guard let contentStart = fromStart.range(of: ">") else { break }
            let afterOpen = fromStart[contentStart.upperBound...]
            guard let end = afterOpen.range(of: close, options: .caseInsensitive) else { break }
            let inner = String(afterOpen[..<end.lowerBound])
            result.append(unescape(stripTags(inner)).trimmingCharacters(in: .whitespacesAndNewlines))
            search = afterOpen[end.upperBound...]
        }
        return result
    }

    static func stripTags(_ html: String) -> String {
        var result = ""
        var inside = false
        for character in html {
            if character == "<" {
                inside = true
            } else if character == ">" {
                inside = false
            } else if !inside {
                result.append(character)
            }
        }
        return result
    }

    static func firstParagraphs(in html: String, limit: Int = 8) -> [String] {
        var result: [String] = []
        var search = html[...]
        while result.count < limit, let start = search.range(of: "<p", options: .caseInsensitive) {
            let fromStart = search[start.lowerBound...]
            guard let contentStart = fromStart.range(of: ">") else { break }
            let afterOpen = fromStart[contentStart.upperBound...]
            guard let end = afterOpen.range(of: "</p>", options: .caseInsensitive) else { break }
            let text = unescape(stripTags(String(afterOpen[..<end.lowerBound])))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                result.append(text)
            }
            search = afterOpen[end.upperBound...]
        }
        return result
    }

    static func headingTables(in html: String) -> [String: [[String]]] {
        var mapped: [String: [[String]]] = [:]
        var search = html[...]
        while let headingStart = search.range(of: "<h2", options: .caseInsensitive) {
            let fromHeading = search[headingStart.lowerBound...]
            guard let headingContent = fromHeading.range(of: ">") else { break }
            let afterOpen = fromHeading[headingContent.upperBound...]
            guard let headingEnd = afterOpen.range(of: "</h2>", options: .caseInsensitive) else { break }
            let title = unescape(stripTags(String(afterOpen[..<headingEnd.lowerBound])))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let afterHeading = afterOpen[headingEnd.upperBound...]
            if let tableStart = afterHeading.range(of: "<table", options: .caseInsensitive) {
                let fromTable = afterHeading[tableStart.lowerBound...]
                if let tableEnd = fromTable.range(of: "</table>", options: .caseInsensitive) {
                    let table = String(fromTable[..<tableEnd.upperBound])
                    mapped[title] = rows(in: table)
                    search = fromTable[tableEnd.upperBound...]
                    continue
                }
            }
            search = afterHeading
        }
        return mapped
    }
}
