import Foundation

nonisolated enum WeightExtractor {
    static let pattern = #"(\d+(?:\.\d+)?)\s*(lbs?|1b|ib|b|oz)\s*@"#

    /** Requires "@" so package sizes like "64 oz" don't count. Accepts OCR misreads of lb: b, 1b, Ib. */
    static func weight(in text: String) -> (pounds: Double, unit: WeightUnit)? {
        let regex = try! Regex(pattern).ignoresCase()
        guard let match = text.firstMatch(of: regex),
              let number = match[1].substring, let value = Double(number),
              let unitText = match[2].substring
        else { return nil }
        let unit: WeightUnit = unitText.lowercased() == "oz" ? .ounces : .pounds
        return (unit.toPounds(value), unit)
    }
}
