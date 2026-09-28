import CoreGraphics
import Testing
import UIKit
@testable import MyFridge

struct OCRServiceTests {
    func box(_ text: String, x: CGFloat, midY: CGFloat, width: CGFloat = 0.3, height: CGFloat = 0.02) -> OCRService.TextBox {
        OCRService.TextBox(text: text, rect: CGRect(x: x, y: midY - height / 2, width: width, height: height))
    }

    @Test func joinsNameAndPriceOnTheSameRow() {
        let rows = OCRService.rows(from: [
            box("3.99 F", x: 0.7, midY: 0.80),
            box("ORG SPINACH", x: 0.1, midY: 0.80),
        ])
        #expect(rows == ["ORG SPINACH 3.99 F"])
    }

    @Test func ordersRowsTopToBottom() {
        let rows = OCRService.rows(from: [
            box("TOTAL", x: 0.1, midY: 0.20),
            box("ORG KALE", x: 0.1, midY: 0.80),
            box("BANANAS", x: 0.1, midY: 0.50),
        ])
        #expect(rows == ["ORG KALE", "BANANAS", "TOTAL"])
    }

    @Test func toleratesSlightSkewButSplitsAdjacentLines() {
        let rows = OCRService.rows(from: [
            box("ORG KALE", x: 0.1, midY: 0.800),
            box("2.99", x: 0.7, midY: 0.794),
            box("BANANAS", x: 0.1, midY: 0.775),
            box("1.23", x: 0.7, midY: 0.776),
        ])
        #expect(rows == ["ORG KALE 2.99", "BANANAS 1.23"])
    }

    @Test func handlesEmptyInput() {
        #expect(OCRService.rows(from: []).isEmpty)
        #expect(OCRService.bestCandidate(among: []) == nil)
    }

    @Test func prefersLaterCandidateThatKeepsTheWeight() {
        #expect(OCRService.bestCandidate(among: ["Qty: @$6.99/lb", "Qty: 1.98lb @$6.99/lb"]) == "Qty: 1.98lb @$6.99/lb")
    }

    @Test(arguments: [
        ["Qty: 1 @ $3.79 each", "Qty: 1 b @ $3.79 each"],
        ["Qty: 1.11 lb @ $18.99/1b", "Qty: 1.11 lb @ $18.99/1b"],
        ["Qty: @$6.99/lb", "Qty: @$6.99/lb"],
    ])
    func keepsFirstCandidateOtherwise(_ candidates: [String]) {
        #expect(OCRService.bestCandidate(among: candidates) == candidates[0])
    }

    @Test func recognizesRenderedReceipt() async throws {
        let lines = [("ORG BABY SPINACH", "3.99"), ("BANANAS", "1.23"), ("SUBTOTAL", "5.22")]
        let font = UIFont.monospacedSystemFont(ofSize: 28, weight: .regular)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 700, height: 260)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 700, height: 260))
            for (index, line) in lines.enumerated() {
                let y = 40 + CGFloat(index) * 60
                (line.0 as NSString).draw(at: CGPoint(x: 30, y: y), withAttributes: [.font: font])
                (line.1 as NSString).draw(at: CGPoint(x: 560, y: y), withAttributes: [.font: font])
            }
        }

        let rows = try await OCRService.recognizeLines(in: [image])
        #expect(rows == ["ORG BABY SPINACH 3.99", "BANANAS 1.23", "SUBTOTAL 5.22"])
    }

    @Test func recognizesWrappedNamesInRenderedScreenshot() async throws {
        let products = [
            ("Organic Valley, Organic Whole Milk, Half Gallon, 64 fl oz", "Qty: 1", "$5.99"),
            ("365 by Whole Foods Market, Organic Baby Spinach, 5 Ounce Container", "Qty: 2", "$3.49"),
        ]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1179, height: 1100)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1179, height: 1100))
            var y: CGFloat = 80
            for (name, quantity, price) in products {
                UIColor.lightGray.setFill()
                context.fill(CGRect(x: 50, y: y, width: 240, height: 240))
                for (text, size, gap) in [(name, 44.0, 12.0), (quantity, 40.0, 8.0), (price, 44.0, 0.0)] {
                    let attributed = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: size)])
                    let height = attributed.boundingRect(
                        with: CGSize(width: 800, height: 1000), options: .usesLineFragmentOrigin, context: nil
                    ).height
                    attributed.draw(with: CGRect(x: 330, y: y, width: 800, height: height), options: .usesLineFragmentOrigin, context: nil)
                    y += height + gap
                }
                y = max(y, y + 150)
            }
        }

        let items = ReceiptLineFilter.screenshotItems(from: try await OCRService.recognizeParagraphs(in: [image]))
        #expect(items == [
            "Organic Valley, Organic Whole Milk, Half Gallon, 64 fl oz | Qty: 1",
            "365 by Whole Foods Market, Organic Baby Spinach, 5 Ounce Container | Qty: 2",
        ])
    }
}
