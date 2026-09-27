import SwiftData
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case today, approvals, clients, templates, booking, connections, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .approvals: "Approvals"
        case .clients: "Clients"
        case .templates: "Templates"
        case .booking: "Booking page"
        case .connections: "Connections"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "calendar"
        case .approvals: "tray.full"
        case .clients: "person.2"
        case .templates: "square.stack.3d.up"
        case .booking: "globe"
        case .connections: "powerplug"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(CalendarService.self) private var calendar
    @AppStorage("didOfferDemoData") private var didOfferDemoData = false
    @SceneStorage("sidebarSelection") private var selection: SidebarItem = .today
    @Query(filter: #Predicate<Draft> { $0.statusRaw == "ready" }) private var readyDrafts: [Draft]
    @Query private var clients: [Client]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Practice") {
                    row(.today)
                    row(.approvals, badge: readyDrafts.count)
                    row(.clients, badge: clients.count)
                    row(.templates)
                }
                Section("Share") {
                    row(.booking)
                    row(.connections)
                }
                Section {
                    row(.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ZStack {
                KitBackground()
                detail
            }
            .navigationTitle(selection.title)
        }
        .task {
            #if DEBUG
            // Lets screenshots open a specific screen: open "Advisor OS.app" --args -section approvals
            if let raw = UserDefaults.standard.string(forKey: "section"), let item = SidebarItem(rawValue: raw) {
                selection = item
            }
            #endif
            let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            if !didOfferDemoData && !isTesting {
                if (try? context.fetchCount(FetchDescriptor<Appointment>())) == 0 {
                    DemoData.load(into: context)
                }
                // Only remember the offer once the data is actually saved.
                if (try? context.save()) != nil { didOfferDemoData = true }
            }
            calendar.start(context: context)
        }
    }

    // The badge must sit inside the tag, or the List can't select the row.
    private func row(_ item: SidebarItem, badge: Int = 0) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .badge(badge)
            .tag(item)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .today: TodayView()
        case .approvals: ApprovalsView()
        case .clients: ClientsView()
        case .templates: TemplatesView()
        case .booking: BookingPageView()
        case .connections: ConnectionsView()
        case .settings: SettingsView()
        }
    }
}
