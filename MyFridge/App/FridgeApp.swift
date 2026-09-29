import SwiftData
import SwiftUI

@main
struct FridgeApp: App {
    private let container: ModelContainer = {
        #if DEBUG
        if UITestLaunch.isActive {
            UITestLaunch.resetSettingsIfAsked()
            return UITestLaunch.makeContainer()
        }
        #endif
        return try! ModelContainer(for: FridgeItem.self)
    }()

    var body: some Scene {
        WindowGroup {
            FridgeListView()
        }
        .modelContainer(container)
    }
}
