import Foundation

enum LaunchArguments {
    static func openFolder(from arguments: [String] = CommandLine.arguments) -> URL? {
        guard let index = arguments.firstIndex(of: "--open"),
              arguments.indices.contains(index + 1)
        else { return nil }
        let raw = arguments[index + 1]
        let expanded = (raw as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
}
