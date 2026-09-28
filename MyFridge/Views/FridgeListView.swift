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

    private let calculator = ExpiryCalculator()

    var body: some View {
        NavigationStack {
            List {
                section("Expired", status: .expired)
                section("Expiring soon", status: .soon)
                section("Fresh", status: .fresh)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Your fridge is empty",
                        systemImage: "refrigerator",
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
                ItemFormView(title: "Edit Item", draft: DraftItem(item)) { draft in
                    FridgeItemStore.update(item, with: draft)
                }
            }
            .sheet(isPresented: $isShowingImportReview) {
                ReviewImportView(importService: importService)
            }
            .sheet(isPresented: $isShowingImportDebug) {
                ImportDebugView(importService: importService)
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
            }
        }
        .task {
            await NotificationService.shared.requestAuthorization()
            await NotificationService.shared.rescheduleAll(items: items)
        }
    }

    @ViewBuilder
    private func section(_ title: String, status: ExpiryStatus) -> some View {
        let sectionItems = items.filter { calculator.status(for: $0.expiryDate, now: now) == status }
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
                }
                .onDelete { offsets in
                    for index in offsets {
                        NotificationService.shared.cancel(for: sectionItems[index])
                        modelContext.delete(sectionItems[index])
                    }
                }
            }
        }
    }
}
