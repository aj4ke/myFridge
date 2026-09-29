import SwiftUI

struct ItemRowView: View {
    let item: FridgeItem
    let now: Date

    private let calculator = ExpiryCalculator()

    var body: some View {
        let color = calculator.status(for: item.expiryDate, now: now).color

        HStack(spacing: 12) {
            Image(systemName: item.category.symbolName)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .foregroundStyle(.secondary)
                    }
                    if item.location != .fridge {
                        Image(systemName: item.location.symbolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(item.location.displayName)
                    }
                }
                HStack(spacing: 4) {
                    Text(calculator.relativeText(for: item.expiryDate, now: now))
                        .foregroundStyle(color)
                    if let details {
                        Text("· \(details)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
            }
        }
    }

    private var details: String? {
        let weight = item.weightPounds.map { item.weightUnit.formatted(pounds: $0) }
        let frozen = item.frozenDate.map { "Frozen \($0.formatted(.dateTime.month(.abbreviated).day()))" }
        let thawed = item.thawedDate == nil ? nil : "Thawed"
        let parts = [frozen, thawed, item.subcategory, weight].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension ExpiryStatus {
    var color: Color {
        switch self {
        case .fresh: .green
        case .soon: .orange
        case .expired: .red
        }
    }

    var rowTint: Color {
        switch self {
        case .fresh: .clear
        case .soon: .yellow.opacity(0.25)
        case .expired: .red.opacity(0.15)
        }
    }
}
