import SwiftUI

struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let isSaved: Bool
    let onSave: (DraftItem) -> Void

    @State private var draft: DraftItem
    @State private var subcategoryChoice: SubcategoryChoice
    @State private var customSubcategory: String
    @State private var weightText: String
    @State private var beforeFrozenToggle: DraftItem?
    private let hadWeight: Bool

    @AppStorage(StorageModes.pantryKey) private var pantryEnabled = false
    @AppStorage(StorageModes.freezerKey) private var freezerEnabled = false

    private let calculator = ExpiryCalculator()

    /**
     * State(initialValue:) only seeds @State on the first init. SwiftUI ignores it after that.
     * isSaved means the item is already in storage, so un-freezing it is a thaw.
     */
    init(title: String, draft: DraftItem, isSaved: Bool = false, onSave: @escaping (DraftItem) -> Void) {
        self.title = title
        self.isSaved = isSaved
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

    private var modes: StorageModes {
        StorageModes(pantry: pantryEnabled, freezer: freezerEnabled)
    }

    private var isFrozen: Bool {
        draft.location == .freezer
    }

    private var showsStoredIn: Bool {
        modes.pantry && !isFrozen && draft.category.allowedLocations.contains(.pantry)
    }

    private var categories: [FoodCategory] {
        FoodCategory.allCases.filter { modes.isEnabled($0.defaultLocation) || $0 == draft.category }
    }

    /** The expiry check only applies when the item was frozen in this form, since that's when its fridge expiry is known. */
    private var freezeWarnings: [String] {
        guard isFrozen else { return [] }
        let before = beforeFrozenToggle.flatMap { $0.location == .freezer ? nil : $0.expiryDate }
        return calculator.freezeWarnings(
            for: draft.category,
            named: draft.name,
            expiringOn: before,
            frozenOn: draft.frozenDate ?? draft.addedDate
        )
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
                        ForEach(categories, id: \.self) { category in
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
                    if showsStoredIn {
                        Picker(
                            "Stored in",
                            selection: Binding(
                                get: { draft.location },
                                set: {
                                    draft.location = $0
                                    draft.expiryEdited = false
                                    draft.recalculateExpiry()
                                }
                            )
                        ) {
                            ForEach([StorageLocation.fridge, .pantry], id: \.self) { location in
                                Label(location.displayName, systemImage: location.symbolName)
                                    .tag(location)
                            }
                        }
                    }

                    Toggle(isOn: Binding(get: { isFrozen }, set: setFrozen)) {
                        Label("Frozen", systemImage: StorageLocation.freezer.symbolName)
                    }
                    .disabled(!modes.freezer)

                    if isFrozen {
                        DatePicker(
                            "Frozen on",
                            selection: Binding(
                                get: { draft.frozenDate ?? draft.addedDate },
                                set: { draft.frozenDate = $0 }
                            ),
                            in: draft.addedDate...max(draft.addedDate, .now),
                            displayedComponents: .date
                        )
                    }
                } footer: {
                    if !modes.freezer {
                        Text("Turn on Freezer in Settings to freeze items.")
                    } else if !freezeWarnings.isEmpty {
                        Text(freezeWarnings.joined(separator: " "))
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    DatePicker(
                        "Added",
                        selection: Binding(get: { draft.addedDate }, set: { draft.setAddedDate($0) }),
                        displayedComponents: .date
                    )

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
                moveToCategoryLocation()
                draft.recalculateExpiry()
            }
            .onChange(of: draft.frozenDate) { draft.recalculateExpiry() }
            .onChange(of: draft.name) { draft.recalculateExpiry() }
        }
    }

    /** Toggling back returns to how the item was before the first toggle. Otherwise a saved item thaws today. */
    private func setFrozen(_ frozen: Bool) {
        if let before = beforeFrozenToggle, (before.location == .freezer) == frozen {
            draft.location = before.location
            draft.frozenDate = before.frozenDate
            draft.thawedDate = before.thawedDate
            draft.expiryDate = before.expiryDate
            draft.expiryEdited = before.expiryEdited
            draft.recalculateExpiry()
            beforeFrozenToggle = nil
            return
        }
        beforeFrozenToggle = draft
        if frozen {
            draft.freeze(on: isSaved ? .now : draft.addedDate)
        } else if isSaved {
            draft.thaw(on: .now, modes: modes)
        } else {
            draft.unfreeze(modes: modes)
        }
    }

    /** New items follow their category into the pantry or freezer. Saved items only move when the category can't stay put. */
    private func moveToCategoryLocation() {
        let category = draft.category
        if !isSaved && !isFrozen && category.defaultLocation == .freezer && modes.freezer {
            setFrozen(true)
        } else if !isSaved && draft.location == .fridge && category.defaultLocation == .pantry && modes.pantry {
            draft.location = .pantry
        } else if !category.allowedLocations.contains(draft.location) {
            draft.location = .fridge
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
        saved.frozenDate = draft.frozenDate.map { calendar.startOfDay(for: $0) }
        onSave(saved)
        dismiss()
    }
}

private enum SubcategoryChoice: Hashable {
    case notSet
    case preset(String)
    case other
}
