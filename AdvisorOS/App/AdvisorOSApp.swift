import SwiftData
import SwiftUI

@main
struct AdvisorOSApp: App {
    @State private var calendar = CalendarService(screenshotMode: Self.isScreenshotMode)
    @State private var drafting = DraftingService()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    private static var isScreenshotMode: Bool {
        #if DEBUG
        ScreenshotMode.isOn
        #else
        false
        #endif
    }

    private let container: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: AdvisorOSApp.isScreenshotMode)
            return try ModelContainer(for: Client.self, Appointment.self, Draft.self, AuditEntry.self, configurations: config)
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
