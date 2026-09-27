import AppKit
import EventKit
import SwiftData
import SwiftUI

struct ConnectionsView: View {
    @Environment(\.modelContext) private var context
    @Environment(CalendarService.self) private var calendar
    @Environment(DraftingService.self) private var drafting
    @State private var confirmingDisconnect = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gapLarge) {
                Text("Every connection is free, for you and your clients. No paid plans in any other tool.")
                    .foregroundStyle(.secondary)

                SectionLabel("Built into macOS")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    calendarCard
                    card(icon: "envelope", title: "Mail drafts", subtitle: "Opens in \(MailService.defaultMailAppName)",
                         text: "Approved emails open as drafts in your default mail app, so they're sent from your own address. Change the default in Mail › Settings › General.",
                         status: Pill(text: "On", tint: Theme.good)) { EmptyView() }
                    aiCard
                    card(icon: "tablecells", title: "CSV import and export", subtitle: "Clients",
                         text: "Bring your book from any CRM export and take it with you any time. Use the buttons in Clients.",
                         status: Pill(text: "Free")) { EmptyView() }
                }

                SectionLabel("Planned · still free")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                    planned("person.crop.square", "Microsoft 365 and Google sign-in", "Adds Teams and Meet links to new bookings through their free APIs.")
                    planned("video", "Zoom", "Creates a Zoom link for each video appointment. Works with free Zoom accounts.")
                    planned("globe", "Web booking page", "Clients book, fill in intake and upload documents. Hosted in Canada.")
                    planned("point.3.connected.trianglepath.dotted", "Webhooks", "Sends booked, changed and approved events to your own CRM.")
                }
            }
            .padding(Theme.paddingLarge)
        }
    }

    private var calendarCard: some View {
        card(icon: "calendar", title: "Calendars on this Mac", subtitle: "iCloud · Google · Exchange",
             text: "Uses the calendars already added in System Settings › Internet Accounts, including Microsoft 365 and Google. Nothing to sign in to.",
             status: calendarStatus) {
            if calendar.isSyncing {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Work calendars").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(calendar.calendars) { cal in
                        Toggle(isOn: Binding(get: { calendar.isWorkCalendar(cal.id) },
                                             set: { calendar.setWorkCalendar(cal.id, $0, context: context) })) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(cgColor: cal.color)).frame(width: 8, height: 8)
                                Text(cal.title)
                                Text(cal.account).foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                        .toggleStyle(.checkbox)
                    }
                    Text("Only events from checked calendars become appointments. Changes in Calendar show up here automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Refresh Now", systemImage: "arrow.clockwise") { calendar.sync(into: context) }
                            .buttonStyle(.glass)
                        Button("Disconnect", role: .destructive) { confirmingDisconnect = true }
                            .buttonStyle(.glass)
                    }
                }
                .confirmationDialog("Disconnect your calendar?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
                    Button("Disconnect", role: .destructive) { calendar.disconnect(context: context) }
                } message: {
                    Text("Appointments imported from your calendar are removed from Advisor OS, with their notes and document checkmarks. Your calendar isn't changed. Appointments you added by hand and demo data stay.")
                }
            } else if calendar.isConnected && !calendar.hasAccess {
                VStack(alignment: .leading, spacing: 8) {
                    Text("macOS calendar access is off, so syncing is paused.").font(.callout)
                    HStack {
                        Button("Allow Access") { Task { await calendar.connect(context: context) } }
                            .buttonStyle(.glassProminent)
                        Button("Disconnect", role: .destructive) { calendar.disconnect(context: context) }
                            .buttonStyle(.glass)
                    }
                    if calendar.status == .denied || calendar.status == .restricted { privacyButton }
                }
            } else if calendar.status == .denied || calendar.status == .restricted {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar access was turned off for Advisor OS. Turn it on in System Settings, then connect.").font(.callout)
                    privacyButton
                }
            } else {
                Button("Connect") { Task { await calendar.connect(context: context) } }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    private var privacyButton: some View {
        Button("Open Privacy Settings") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(.glass)
    }

    private var calendarStatus: Pill {
        if calendar.isSyncing { return Pill(text: "Connected", tint: Theme.good) }
        if calendar.isConnected { return Pill(text: "Paused", tint: Theme.warn) }
        return Pill(text: "Not connected")
    }

    private var aiCard: some View {
        let engine = drafting.engine
        let text: String = switch engine {
        case .onDevice: "Drafts are written by Apple's on-device model. Client data never leaves this Mac, and it costs nothing."
        case .template(let reason): "\(reason) Until then, drafts use plain templates you can edit."
        }
        return card(icon: "sparkles", title: "Drafting", subtitle: engine.label, text: text,
                    status: Pill(text: engine == .onDevice ? "On this Mac" : "Templates", tint: engine == .onDevice ? Theme.good : Theme.warn)) { EmptyView() }
    }

    private func planned(_ icon: String, _ title: String, _ text: String) -> some View {
        card(icon: icon, title: title, subtitle: "Planned", text: text, status: Pill(text: "Planned")) { EmptyView() }
            .opacity(0.75)
    }

    private func card<Actions: View>(icon: String, title: String, subtitle: String, text: String, status: Pill,
                                     @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular, in: .rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                status
            }
            Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            actions()
        }
        .glassCard(padding: 16)
    }
}
