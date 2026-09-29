import SwiftData
import SwiftUI

struct FridgeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \FridgeItem.expiryDate) private var items: [FridgeItem]

    @State private var isAdding = false
    @State private var editingItem: FridgeItem?
    @State private var now = Date.now
    @State private var importService = ImportService()
    @State private var isShowingImportDebug = false
    @State private var isShowingImportReview = false
    @State private var isShowingSettings = false
    @State private var filter: StorageLocation?
    @State private var itemToFreeze: FridgeItem?

    @AppStorage(StorageModes.pantryKey) private var pantryEnabled = false
    @AppStorage(StorageModes.freezerKey) private var freezerEnabled = false

    private let calculator = ExpiryCalculator()

    private var modes: StorageModes {
        StorageModes(pantry: pantryEnabled, freezer: freezerEnabled)
    }

    private var visibleItems: [FridgeItem] {
        modes.visible(items).filter { filter == nil || $0.location == filter }
    }

    var body: some View {
        NavigationStack {
            List {
                section("Expired", status: .expired)
                section("Expiring soon", status: .soon)
                section("Fresh", status: .fresh)
            }
            .overlay {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        filter == nil ? "Your fridge is empty" : "Nothing here yet",
                        systemImage: filter?.symbolName ?? "refrigerator",
                        description: Text("Tap + to add an item.")
                    )
                }
            }
            .overlay {
                if let progress = importService.progress {
                    ProgressView(progress)
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .navigationTitle("MyFridge")
            .toolbar {
                ToolbarItem(placement: .largeTitle) {
                    Text("MyFridge")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onLongPressGesture {
                            isShowingImportDebug = true
                        }
                }
                if modes.enabledLocations.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        filterMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ImportMenu(
                        importService: importService,
                        onAddManually: { isAdding = true },
                        onImportFinished: { isShowingImportReview = true }
                    )
                }
            }
            .sheet(isPresented: $isAdding) {
                ItemFormView(title: "Add Item", draft: DraftItem()) { draft in
                    FridgeItemStore.add(draft, to: modelContext)
                }
            }
            .sheet(item: $editingItem) { item in
                ItemFormView(title: "Edit Item", draft: DraftItem(item), isSaved: true) { draft in
                    FridgeItemStore.update(item, with: draft)
                }
            }
            .sheet(isPresented: $isShowingImportReview) {
                ReviewImportView(importService: importService)
            }
            .sheet(isPresented: $isShowingImportDebug) {
                ImportDebugView(importService: importService)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { importService.errorMessage != nil },
                    set: { if !$0 { importService.errorMessage = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(importService.errorMessage ?? "")
            }
            .confirmationDialog(
                "Freeze anyway?",
                isPresented: Binding(
                    get: { itemToFreeze != nil },
                    set: { if !$0 { itemToFreeze = nil } }
                ),
                titleVisibility: .visible,
                presenting: itemToFreeze
            ) { item in
                Button("Freeze") {
                    FridgeItemStore.freeze(item)
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text(freezeWarnings(for: item).joined(separator: " "))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
                /* Puts back anything changed in Reminders while the app was away. */
                if ReminderService.shared.isEnabled {
                    Task { await ExpiryAlerts.rescheduleAll(items: modes.visible(items)) }
                }
            }
        }
        .onChange(of: modes) {
            if let filter, !modes.isEnabled(filter) || modes.enabledLocations.count == 1 {
                self.filter = nil
            }
        }
        .task {
            #if DEBUG
            /* UI tests skip the notification prompt, since a system alert would block every tap. */
            if UITestLaunch.isActive {
                if let items = UITestLaunch.importItems {
                    importService.loadForUITest(items)
                    isShowingImportReview = true
                }
                return
            }
            #endif
            await NotificationService.shared.requestAuthorization()
            await ExpiryAlerts.rescheduleAll(items: modes.visible(items))
        }
    }

    private var filterMenu: some View {
        Menu("Filter", systemImage: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") {
            Picker("Show", selection: $filter) {
                Label("All", systemImage: "square.grid.2x2").tag(StorageLocation?.none)
                ForEach(modes.enabledLocations, id: \.self) { location in
                    Label(location.displayName, systemImage: location.symbolName).tag(StorageLocation?.some(location))
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, status: ExpiryStatus) -> some View {
        let sectionItems = visibleItems.filter { calculator.status(for: $0.expiryDate, now: now) == status }
        if !sectionItems.isEmpty {
            Section(title) {
                ForEach(sectionItems) { item in
                    Button {
                        editingItem = item
                    } label: {
                        ItemRowView(item: item, now: now)
                    }
                    .tint(.primary)
                    .listRowBackground(Color(.secondarySystemGroupedBackground).overlay(status.rowTint))
                    /* swipeActions replaces the swipe-to-delete that onDelete adds, so Delete has to be listed here. */
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            ExpiryAlerts.cancel(for: item)
                            modelContext.delete(item)
                        }
                        if item.location == .freezer {
                            Button("Thaw", systemImage: "thermometer.sun.fill") {
                                FridgeItemStore.thaw(item, modes: modes)
                            }
                            .tint(.orange)
                        } else if modes.freezer {
                            Button("Freeze", systemImage: "snowflake") {
                                freeze(item)
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
    }

    /** Warnings never block freezing, but a swipe is quick, so they're confirmed first. */
    private func freeze(_ item: FridgeItem) {
        if freezeWarnings(for: item).isEmpty {
            FridgeItemStore.freeze(item)
        } else {
            itemToFreeze = item
        }
    }

    private func freezeWarnings(for item: FridgeItem) -> [String] {
        calculator.freezeWarnings(for: item.category, named: item.name, expiringOn: item.expiryDate, frozenOn: .now)
    }
}
