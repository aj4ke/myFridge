import Foundation

/** Words that can appear in product names, like TOTAL, only match at the start of a line. */
nonisolated enum ReceiptLineFilter {
    static let pricePattern = #"^[-$\s]*\d{1,4}[.,]\d{2}(\s*[A-Z]{1,2})?$"#

    static let quantityPattern = #"^QTY\b"#

    static let orderHeaderPattern = #"^ITEMS IN YOUR ORDER$"#

    static let dropPatterns: [String] = [
        #"^[^A-Z0-9]+$"#,
        #"^\d+$"#,
        #"^\W*[A-Z]\W*$"#,

        pricePattern,

        #"^\W*(SUB\s?TOTAL|TOTAL|BALANCE)\b"#,
        #"\b(SUB\s?TOTAL|ORDER TOTAL|GRAND TOTAL|BALANCE DUE)\b"#,

        #"\b(TAX|CHANGE|VISA|MASTERCARD|DEBIT|CREDIT|CASH|AUTH|APPROVED|THANK YOU)\b"#,
        #"[*X]{4,}\s*\d{4}\b"#,

        #"\(?\b\d{3}\)?[\s.-]?\d{3}[\s.-]\d{4}\b"#,

        #"^\d{1,6}\s+[A-Z0-9 .]+\s(ST|STREET|AVE|AVENUE|RD|ROAD|BLVD|DR|DRIVE|LN|LANE|WAY|PKWY|HWY)\.?$"#,
        #"\b[A-Z]{2}\s+\d{5}(-\d{4})?$"#,

        #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,
        #"\b(JAN(UARY)?|FEB(RUARY)?|MAR(CH)?|APR(IL)?|MAY|JUNE?|JULY?|AUG(UST)?|SEPT?(EMBER)?|OCT(OBER)?|NOV(EMBER)?|DEC(EMBER)?)\.?\s+\d{1,2}\b"#,
        #"\b\d{1,2}:\d{2}\b"#,

        #"\d{10,}"#,
        #"^[\d\s-]{12,}$"#,
        #"\b\d{3}-\d{7}-\d{7}\b"#,

        #"\bSEARCH OR ASK A QUESTION\b"#,
        orderHeaderPattern,
        #"\bTARE WEIGHT\b"#,
        #"\bCHECKOUT BAG\b"#,
        #"\bBAG FEE\b"#,
        #"^COLLAPSE\b"#,
    ]

    static let detailLinePattern = "^(" + WeightExtractor.pattern + #"|\d+\s*@)"#

    /** Joins weight and count lines onto the item above as "item | detail". */
    static func filter(_ lines: [String]) -> [String] {
        var kept: [String] = []
        for line in lines.map({ $0.trimmingCharacters(in: .whitespaces) }) where !isJunk(line) {
            if matches(line, detailLinePattern), let item = kept.popLast() {
                kept.append(item + " | " + line)
            } else {
                kept.append(line)
            }
        }
        return kept
    }

    /**
     * An item is the text since the previous item, ending at its Qty line, or at its price on pages without Qty lines.
     * Prices are skipped when there are Qty lines since OCR can place one between two lines of a name.
     * Text above "Items in your order" is the store header. Pages with neither Qty nor prices give one entry per paragraph.
     */
    static func screenshotItems(from paragraphs: [[String]]) -> [String] {
        let lines = paragraphs.joined().map { $0.trimmingCharacters(in: .whitespaces) }
        let hasQuantities = lines.contains { matches($0, quantityPattern) }

        guard hasQuantities || lines.contains(where: { matches($0, pricePattern) }) else {
            return paragraphs
                .map { filter($0).joined(separator: " ") }
                .filter { !$0.isEmpty }
        }

        var items: [String] = []
        var name: [String] = []
        for line in lines {
            if matches(line, orderHeaderPattern) {
                name = []
            } else if matches(line, quantityPattern) {
                if !name.isEmpty {
                    items.append(name.joined(separator: " ") + " | " + line)
                }
                name = []
            } else if matches(line, pricePattern) {
                guard !hasQuantities else { continue }
                if !name.isEmpty {
                    items.append(name.joined(separator: " "))
                }
                name = []
            } else if !isJunk(line) {
                name.append(line)
            }
        }
        if !name.isEmpty {
            items.append(name.joined(separator: " "))
        }
        return items
    }

    private static func isJunk(_ line: String) -> Bool {
        line.isEmpty || dropPatterns.contains { matches(line, $0) }
    }

    private static func matches(_ line: String, _ pattern: String) -> Bool {
        line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
