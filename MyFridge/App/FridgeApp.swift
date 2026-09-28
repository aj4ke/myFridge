import SwiftData
import SwiftUI

@main
struct FridgeApp: App {
    var body: some Scene {
        WindowGroup {
            FridgeListView()
        }
        .modelContainer(for: FridgeItem.self)
    }
}
