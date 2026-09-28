import Foundation

/** Display unit only. Weights are always stored in pounds. */
nonisolated enum WeightUnit: String, CaseIterable {
    case pounds = "lb"
    case ounces = "oz"

    func toPounds(_ value: Double) -> Double {
        switch self {
        case .pounds: value
        case .ounces: value / 16
        }
    }

    func value(fromPounds pounds: Double) -> Double {
        switch self {
        case .pounds: pounds
        case .ounces: pounds * 16
        }
    }

    func formatted(pounds: Double) -> String {
        "\(value(fromPounds: pounds).formatted(.number.precision(.fractionLength(0...2)))) \(rawValue)"
    }
}
