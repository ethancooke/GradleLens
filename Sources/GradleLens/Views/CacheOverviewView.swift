import GradleLensCore
import SwiftUI

struct CacheOverviewView: View {
    let overview: BuildCacheOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if overview.exists {
                LabeledContent("Path", value: PathFormat.abbreviatingHome(overview.path))
                LabeledContent("Entries", value: overview.entryCount.formatted())
                LabeledContent("Total size", value: ByteFormat.display(overview.totalBytes))
                LabeledContent("Average", value: ByteFormat.display(overview.averageBytes))
                if let oldest = overview.oldestEntry {
                    LabeledContent("Oldest", value: oldest.formatted(date: .abbreviated, time: .omitted))
                }
                if let newest = overview.newestEntry {
                    LabeledContent("Newest", value: newest.formatted(date: .abbreviated, time: .omitted))
                }
                if !overview.largestEntries.isEmpty {
                    Divider()
                    Text("Largest entries")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(overview.largestEntries) { entry in
                        HStack {
                            Text(entry.name)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(ByteFormat.display(entry.byteCount))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Reveal cache folder") {
                    WorkspaceOpener.reveal(overview.pathURL)
                }
                .padding(.top, 4)
            } else {
                Text("No local build cache was found at \(PathFormat.abbreviatingHome(overview.path)).")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
