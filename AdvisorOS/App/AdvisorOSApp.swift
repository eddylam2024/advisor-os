import SwiftData
import SwiftUI

@main
struct AdvisorOSApp: App {
    @State private var calendar = CalendarService()
    @State private var drafting = DraftingService()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Client.self, Appointment.self, Draft.self, AuditEntry.self)
        } catch {
            fatalError("Couldn't open the Advisor OS database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup("Advisor OS", id: "main") {
            ContentView()
                .environment(calendar)
                .environment(drafting)
                .frame(minWidth: 960, minHeight: 620)
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 780)

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarView()
                .environment(calendar)
                .modelContainer(container)
        } label: {
            MenuBarLabel()
                .modelContainer(container)
        }
        .menuBarExtraStyle(.window)
    }
}
