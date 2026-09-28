import ImageIO
import UIKit
import Vision

/**
 * The project defaults every type to @MainActor, so pure logic types like this are marked nonisolated.
 * @concurrent runs Vision off the main thread. Without it, a nonisolated async func runs on the caller's actor.
 */
nonisolated enum OCRService {
    @concurrent
    static func recognizeLines(in images: [UIImage]) async throws -> [String] {
        var lines: [String] = []
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            lines += try await recognizeLines(in: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
        }
        return lines
    }

    /** Language correction is off because it rewrites receipt abbreviations. */
    @concurrent
    static func recognizeLines(in image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let observations = try await request.perform(on: image, orientation: orientation)
        let boxes = observations.compactMap { observation in
            observation.topCandidates(1).first.map { TextBox(text: $0.string, rect: observation.boundingBox.cgRect) }
        }
        return rows(from: boxes)
    }

    /** Product names wrap across lines, so screenshots are grouped by paragraph. */
    @concurrent
    static func recognizeParagraphs(in images: [UIImage]) async throws -> [[String]] {
        var paragraphs: [[String]] = []
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
            var boxes: [ParagraphBox] = []
            for observation in observations {
                boxes += observation.document.paragraphs.map { paragraph in
                    ParagraphBox(
                        lines: paragraph.lines.compactMap { bestCandidate(among: $0.topCandidates(3).map(\.string)) },
                        rect: paragraph.boundingRegion.boundingBox.cgRect
                    )
                }
            }
            paragraphs += readingOrder(boxes)
        }
        return paragraphs
    }

    /**
     * On iPhone, Vision reads a whole column before the next, which puts the store logo after the items.
     * Paragraphs whose tops are within half a line share a row and read left to right, like rows(from:).
     */
    static func readingOrder(_ paragraphs: [ParagraphBox]) -> [[String]] {
        var rows: [[ParagraphBox]] = []
        for paragraph in paragraphs.sorted(by: { $0.rect.maxY > $1.rect.maxY }) {
            if let anchor = rows.last?.first,
               anchor.rect.maxY - paragraph.rect.maxY < min(anchor.lineHeight, paragraph.lineHeight) / 2 {
                rows[rows.count - 1].append(paragraph)
            } else {
                rows.append([paragraph])
            }
        }
        return rows.flatMap { $0.sorted { $0.rect.minX < $1.rect.minX } }.map(\.lines)
    }

    /** The first guess for a per-pound Qty line can drop the weight ("Qty: @$6.99/lb") while a later guess keeps it. */
    static func bestCandidate(among candidates: [String]) -> String? {
        guard let first = candidates.first,
              first.range(of: #"/\s*(lbs?|1b|ib|oz)\b"#, options: [.regularExpression, .caseInsensitive]) != nil,
              WeightExtractor.weight(in: first) == nil
        else { return candidates.first }
        return candidates.first { WeightExtractor.weight(in: $0) != nil } ?? first
    }

    /** rect is normalized 0 to 1 with a bottom-left origin, like Vision. */
    struct TextBox {
        let text: String
        let rect: CGRect
    }

    /** Same coordinates as TextBox. */
    struct ParagraphBox {
        let lines: [String]
        let rect: CGRect

        var lineHeight: CGFloat {
            rect.height / CGFloat(max(lines.count, 1))
        }
    }

    /** Boxes whose centers are within half a line height share a row. */
    static func rows(from boxes: [TextBox]) -> [String] {
        var rows: [[TextBox]] = []
        for box in boxes.sorted(by: { $0.rect.midY > $1.rect.midY }) {
            if let anchor = rows.last?.first,
               abs(anchor.rect.midY - box.rect.midY) < min(anchor.rect.height, box.rect.height) / 2 {
                rows[rows.count - 1].append(box)
            } else {
                rows.append([box])
            }
        }
        return rows.map { row in
            row.sorted { $0.rect.minX < $1.rect.minX }.map(\.text).joined(separator: " ")
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
