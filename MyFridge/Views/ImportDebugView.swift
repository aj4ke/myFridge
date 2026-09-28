import SwiftUI

/** Opened by long-pressing the MyFridge title. */
struct ImportDebugView: View {
    @Environment(\.dismiss) private var dismiss

    let importService: ImportService

    var body: some View {
        NavigationStack {
            List {
                if importService.lastRawBlocks.isEmpty {
                    ContentUnavailableView(
                        "No import yet",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Scan a receipt or import screenshots first.")
                    )
                } else {
                    lineSection("Filtered", lines: importService.lastFilteredLines, showsWeight: true)
                    lineSection("Raw OCR", lines: importService.lastRawBlocks)
                }
            }
            .navigationTitle("Last Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu("Share", systemImage: "square.and.arrow.up") {
                        ShareLink("Raw Lines", item: rawExportText)
                        ShareLink("Filtered Lines", item: importService.lastFilteredLines.joined(separator: "\n"))
                    }
                    .disabled(importService.lastRawBlocks.isEmpty)
                }
            }
        }
    }

    private var rawExportText: String {
        importService.lastRawBlocks.joined(separator: importService.lastSource == .screenshot ? "\n\n" : "\n")
    }

    private func lineSection(_ title: String, lines: [String], showsWeight: Bool = false) -> some View {
        Section("\(title) (\(lines.count))") {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    if showsWeight, let weight = WeightExtractor.weight(in: line) {
                        Text("Weight: \(weight.unit.formatted(pounds: weight.pounds))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }
}
