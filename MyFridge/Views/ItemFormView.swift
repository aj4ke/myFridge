import SwiftUI

struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSave: (DraftItem) -> Void

    @State private var draft: DraftItem
    @State private var subcategoryChoice: SubcategoryChoice
    @State private var customSubcategory: String
    @State private var weightText: String
    private let hadWeight: Bool

    /** State(initialValue:) only seeds @State on the first init. SwiftUI ignores it after that. */
    init(title: String, draft: DraftItem, onSave: @escaping (DraftItem) -> Void) {
        self.title = title
        self.onSave = onSave
        _draft = State(initialValue: draft)
        if let subcategory = draft.subcategory, !draft.category.subcategories.contains(subcategory) {
            _subcategoryChoice = State(initialValue: .other)
            _customSubcategory = State(initialValue: subcategory)
        } else {
            _subcategoryChoice = State(initialValue: draft.subcategory.map { .preset($0) } ?? .notSet)
            _customSubcategory = State(initialValue: "")
        }
        _weightText = State(initialValue: draft.weightPounds.map {
            draft.weightUnit.value(fromPounds: $0).formatted(.number.precision(.fractionLength(0...2)))
        } ?? "")
        hadWeight = draft.weightPounds != nil
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var subcategory: String? {
        switch subcategoryChoice {
        case .notSet:
            return nil
        case .preset(let name):
            return name
        case .other:
            let trimmed = customSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private var showsWeight: Bool {
        draft.category.tracksWeight || hadWeight
    }

    private var weightPounds: Double? {
        guard showsWeight, let value = try? Double(weightText, format: .number) else { return nil }
        return draft.weightUnit.toPounds(value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)

                    Picker(
                        "Category",
                        selection: Binding(
                            get: { draft.category },
                            set: {
                                /* Reset here, not in onChange, or the Subcategory picker renders a tag that no longer exists. */
                                if $0 != draft.category, case .preset = subcategoryChoice {
                                    subcategoryChoice = .notSet
                                }
                                draft.category = $0
                            }
                        )
                    ) {
                        ForEach(FoodCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }

                    Picker("Subcategory", selection: $subcategoryChoice) {
                        Text("None").tag(SubcategoryChoice.notSet)
                        ForEach(draft.category.subcategories, id: \.self) { name in
                            Text(name).tag(SubcategoryChoice.preset(name))
                        }
                        Text("Other…").tag(SubcategoryChoice.other)
                    }

                    if subcategoryChoice == .other {
                        TextField("Subcategory", text: $customSubcategory)
                    }
                }

                Section {
                    Stepper("Quantity: \(draft.quantity)", value: $draft.quantity, in: 1...99)

                    if showsWeight {
                        HStack {
                            TextField("Weight", text: $weightText)
                                .keyboardType(.decimalPad)
                            Picker("Unit", selection: $draft.weightUnit) {
                                ForEach(WeightUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .fixedSize()
                        }
                    }
                }

                Section {
                    DatePicker("Added", selection: $draft.addedDate, displayedComponents: .date)

                    DatePicker(
                        "Expires",
                        selection: Binding(
                            get: { draft.expiryDate },
                            set: {
                                draft.expiryDate = $0
                                draft.expiryEdited = true
                            }
                        ),
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) {
                        save()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onChange(of: draft.category) {
                draft.expiryEdited = false
                draft.recalculateExpiry()
            }
            .onChange(of: draft.addedDate) { draft.recalculateExpiry() }
            .onChange(of: draft.name) { draft.recalculateExpiry() }
        }
    }

    private func save() {
        let calendar = Calendar.current
        var saved = draft
        saved.name = trimmedName
        saved.subcategory = subcategory
        saved.weightPounds = weightPounds
        saved.addedDate = calendar.startOfDay(for: draft.addedDate)
        saved.expiryDate = calendar.startOfDay(for: draft.expiryDate)
        onSave(saved)
        dismiss()
    }
}

private enum SubcategoryChoice: Hashable {
    case notSet
    case preset(String)
    case other
}
