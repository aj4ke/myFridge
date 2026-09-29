import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [FridgeItem]

    @AppStorage(StorageModes.pantryKey) private var pantryEnabled = false
    @AppStorage(StorageModes.freezerKey) private var freezerEnabled = false
    @AppStorage(ReminderService.enabledKey) private var remindersEnabled = false
    @State private var locationToHide: StorageLocation?
    @State private var countToClear: Int?
    @State private var isConfirmingListDelete = false
    @State private var isShowingRemindersAccessAlert = false
    @State private var remindersError: String?

    private var modes: StorageModes {
        StorageModes(pantry: pantryEnabled, freezer: freezerEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Storage") {
                    toggle(
                        .pantry,
                        isOn: $pantryEnabled,
                        description: "Track bread, pasta, canned goods and other shelf-stable food."
                    )

                    toggle(
                        .freezer,
                        isOn: $freezerEnabled,
                        description: "Track frozen food and freeze items to extend their dates."
                    )
                }

                Section("Alerts") {
                    Toggle(
                        isOn: Binding(
                            get: { remindersEnabled },
                            set: { newValue in
                                if newValue {
                                    Task { await turnOnReminders() }
                                } else {
                                    isConfirmingListDelete = true
                                }
                            }
                        )
                    ) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reminders")
                                Text("Add expiry dates to a MyFridge list in Reminders instead of sending notifications.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checklist")
                        }
                    }
                }

                Section {
                    Button("Clear All Items", role: .destructive) {
                        countToClear = items.count
                    }
                    .disabled(items.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        dismiss()
                    }
                }
            }
            .alert(
                hideTitle,
                isPresented: Binding(
                    get: { locationToHide != nil },
                    set: { if !$0 { locationToHide = nil } }
                ),
                presenting: locationToHide
            ) { location in
                Button("Hide Items", role: .destructive) {
                    setEnabled(location, false)
                }
                Button("Cancel", role: .cancel) {}
            } message: { location in
                Text("They'll come back when you turn \(location.displayName) on again. Reminders for them are paused.")
            }
            .alert(
                countToClear == 1 ? "Delete 1 item?" : "Delete all \(countToClear ?? 0) items?",
                isPresented: Binding(
                    get: { countToClear != nil },
                    set: { if !$0 { countToClear = nil } }
                )
            ) {
                Button("Delete All", role: .destructive) {
                    try? FridgeItemStore.deleteAll(from: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
            .alert("Delete the MyFridge list?", isPresented: $isConfirmingListDelete) {
                Button("Delete List", role: .destructive) {
                    remindersEnabled = false
                    Task {
                        try? await ReminderService.shared.deleteList()
                        await ExpiryAlerts.rescheduleAll(items: modes.visible(items))
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its reminders are removed from Reminders, and MyFridge goes back to sending its own notifications.")
            }
            .alert("Allow Reminders Access", isPresented: $isShowingRemindersAccessAlert) {
                Button("Open Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("MyFridge needs Full Access to Reminders to keep the MyFridge list up to date.")
            }
            .alert(
                "Couldn't Set Up Reminders",
                isPresented: Binding(
                    get: { remindersError != nil },
                    set: { if !$0 { remindersError = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(remindersError ?? "")
            }
            .onChange(of: modes) {
                Task { await ExpiryAlerts.rescheduleAll(items: modes.visible(items)) }
            }
        }
    }

    private var hideTitle: String {
        guard let locationToHide else { return "" }
        let count = itemCount(in: locationToHide)
        let name = locationToHide.displayName.lowercased()
        return count == 1 ? "Hide 1 \(name) item?" : "Hide \(count) \(name) items?"
    }

    private func itemCount(in location: StorageLocation) -> Int {
        items.count { $0.location == location }
    }

    /** Turning a location off asks first when it has items, so the setter holds the change until the alert. */
    private func toggle(_ location: StorageLocation, isOn: Binding<Bool>, description: String) -> some View {
        Toggle(
            isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    if !newValue && itemCount(in: location) > 0 {
                        locationToHide = location
                    } else {
                        isOn.wrappedValue = newValue
                    }
                }
            )
        ) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: location.symbolName)
            }
        }
    }

    /** The toggle only turns on once the MyFridge list is filled, and then the app's own notifications are cleared. */
    private func turnOnReminders() async {
        guard await ReminderService.shared.requestAccess() else {
            isShowingRemindersAccessAlert = true
            return
        }
        do {
            try await ReminderService.shared.sync(modes.visible(items))
        } catch {
            remindersError = error.localizedDescription
            return
        }
        remindersEnabled = true
        await NotificationService.shared.rescheduleAll(items: [])
    }

    private func setEnabled(_ location: StorageLocation, _ enabled: Bool) {
        switch location {
        case .fridge: break
        case .pantry: pantryEnabled = enabled
        case .freezer: freezerEnabled = enabled
        }
    }
}
