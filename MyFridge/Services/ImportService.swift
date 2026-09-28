import FoundationModels
import PhotosUI
import SwiftUI
import UIKit

@Observable
final class ImportService {
    private(set) var progress: String?
    private(set) var lastSource: ItemSource?
    private(set) var lastRawBlocks: [String] = []
    private(set) var lastFilteredLines: [String] = []
    private(set) var lastItems: [ParsedItem] = []
    private(set) var lastSkippedLines: [String] = []
    private(set) var fallbackReason: String?
    private(set) var lastPurchaseDate: Date?
    var errorMessage: String?

    func importScannedPages(_ pages: [UIImage]) async -> Bool {
        progress = "Reading text…"
        defer { progress = nil }
        do {
            let rows = try await OCRService.recognizeLines(in: pages)
            lastSource = .receipt
            lastRawBlocks = rows
            lastFilteredLines = ReceiptLineFilter.filter(rows)
            lastPurchaseDate = PurchaseDateExtractor.date(in: rows)
            try await parseFilteredLines()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func importScreenshots(_ items: [PhotosPickerItem]) async -> Bool {
        progress = "Reading text…"
        defer { progress = nil }
        do {
            var images: [UIImage] = []
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            let paragraphs = try await OCRService.recognizeParagraphs(in: images)
            lastSource = .screenshot
            lastRawBlocks = paragraphs.map { $0.joined(separator: "\n") }
            lastFilteredLines = ReceiptLineFilter.screenshotItems(from: paragraphs)
            lastPurchaseDate = PurchaseDateExtractor.date(in: Array(paragraphs.joined()))
            try await parseFilteredLines()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func makeDrafts(addedOn date: Date) -> [DraftItem] {
        Self.drafts(from: lastItems, lines: lastFilteredLines, source: lastSource ?? .receipt, addedOn: date)
    }

    static func drafts(
        from items: [ParsedItem],
        lines: [String],
        source: ItemSource,
        addedOn date: Date,
        calculator: ExpiryCalculator = ExpiryCalculator()
    ) -> [DraftItem] {
        items.map { item in
            DraftItem(
                name: item.name,
                category: item.category,
                quantity: item.quantity,
                weight: weight(for: item, in: lines),
                addedDate: date,
                source: source,
                needsRefrigeration: item.needsRefrigeration,
                calculator: calculator
            )
        }
    }

    static func weight(for item: ParsedItem, in lines: [String]) -> (pounds: Double, unit: WeightUnit)? {
        guard lines.indices.contains(item.line - 1) else { return nil }
        return WeightExtractor.weight(in: lines[item.line - 1])
    }

    /** The model can report available and still failc, so errors fall back too. */
    private func parseFilteredLines() async throws {
        progress = "Sorting items…"
        let source = lastSource ?? .receipt
        let result: ParseResult
        switch SystemLanguageModel.default.availability {
        case .available:
            do {
                result = try await FoundationModelsParser().parse(lines: lastFilteredLines, source: source)
                fallbackReason = nil
            } catch {
                result = try await FallbackParser().parse(lines: lastFilteredLines, source: source)
                fallbackReason = "The on-device model couldn't run (\(error.localizedDescription))."
            }
        case .unavailable(let reason):
            result = try await FallbackParser().parse(lines: lastFilteredLines, source: source)
            fallbackReason = FoundationModelsParser.ParserError.unavailable(reason).localizedDescription
        }
        lastItems = result.items
        lastSkippedLines = result.skippedLines
    }
}
