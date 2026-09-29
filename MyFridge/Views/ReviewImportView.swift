import SwiftData
import SwiftUI

struct ReviewImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let importService: ImportService

    @State private var drafts: [DraftItem]
    @State private var purchaseDate: Date
    @State private var showsSkippedItems = false
    @State private var editingDraft: DraftItem?

    init(importService: ImportService) {
        self.importService = importService
        let date = importService.lastPurchaseDate ?? Calendar.current.startOfDay(for: .now)
        _purchaseDate = State(initialValue: date)
        _drafts = State(initialValue: importService.makeDrafts(addedOn: date))
    }

    private var includedCount: Int {
        drafts.count(where: \.isIncluded)
    }

    private var hiddenCount: Int {
        drafts.count { $0.skipReason != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if let reason = importService.fallbackReason {
                    banner("\(reason) Items weren't sorted into categories.")
                }
                if !importService.lastSkippedLines.isEmpty {
                    banner("\(importService.lastSkippedLines.count) lines were skipped by the on-device model.")
                }

                Section {
                    DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date)
                }

                Section {
                    ForEach($drafts) { $draft in
                        if showsSkippedItems || draft.skipReason == nil {
                            DraftRow(draft: $draft) {
                                editingDraft = draft
                            }
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    drafts.removeAll { $0.id == draft.id }
                                }
                            }
                        }
                    }
                }

                if hiddenCount > 0 {
                    Toggle(hiddenCount == 1 ? "Show 1 other item" : "Show \(hiddenCount) other items", isOn: $showsSkippedItems)
                }
            }
            .overlay {
                if drafts.isEmpty {
                    ContentUnavailableView(
                        "No items found",
                        systemImage: "cart",
                        description: Text("Long-press the MyFridge title to see what was read.")
                    )
                }
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(includedCount == 1 ? "Add 1 Item" : "Add \(includedCount) Items") {
                        save()
                    }
                    .disabled(includedCount == 0)
                }
            }
            .onChange(of: purchaseDate) {
                for index in drafts.indices {
                    drafts[index].setAddedDate(purchaseDate)
                }
            }
            .sheet(item: $editingDraft) { draft in
                ItemFormView(title: "Edit Item", draft: draft) { edited in
                    if let index = drafts.firstIndex(where: { $0.id == edited.id }) {
                        drafts[index] = edited
                    }
                }
            }
        }
    }

    private func banner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.orange)
    }

    private func save() {
        let included = drafts.filter(\.isIncluded)
        Task {
            try? await FridgeItemStore.addImported(included, to: modelContext)
            dismiss()
        }
    }
}

private struct DraftRow: View {
    @Binding var draft: DraftItem
    let onEdit: () -> Void

    private let calculator = ExpiryCalculator()

    private var details: String {
        [
            draft.category.displayName,
            draft.weightPounds.map { draft.weightUnit.formatted(pounds: $0) },
            calculator.relativeText(for: draft.expiryDate),
            note,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var note: String? {
        switch draft.skipReason {
        case .notFood: "Not food"
        case .locationOff(let location): "\(location.displayName) is off"
        case nil: draft.location == .fridge ? nil : draft.location.displayName
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                draft.isIncluded.toggle()
            } label: {
                Image(systemName: draft.isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(draft.isIncluded ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(draft.isIncluded ? "Included" : "Not included")

            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: draft.category.symbolName)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(draft.name)
                                .foregroundStyle(.primary)
                            if draft.quantity > 1 {
                                Text("×\(draft.quantity)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.borderless)
        }
        .opacity(draft.isIncluded ? 1 : 0.5)
    }
}
