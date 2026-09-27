import SwiftData
import SwiftUI

private func upcomingToday(_ appointments: [Appointment]) -> [Appointment] {
    appointments.filter { Calendar.current.isDateInToday($0.start) && $0.end >= .now }
}

struct MenuBarLabel: View {
    @Query(sort: \Appointment.start) private var appointments: [Appointment]

    var body: some View {
        if let next = upcomingToday(appointments).first {
            Label("\(next.start.formatted(date: .omitted, time: .shortened)) \(next.clientName)", systemImage: "calendar")
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: "calendar")
        }
    }
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Appointment.start) private var appointments: [Appointment]

    var body: some View {
        let today = upcomingToday(appointments)
        VStack(alignment: .leading, spacing: 10) {
            Text("Still to come today").font(.headline)
            if today.isEmpty {
                Text("Nothing else today.").foregroundStyle(.secondary)
            }
            ForEach(today) { a in
                HStack(spacing: 10) {
                    Text(a.start.formatted(date: .omitted, time: .shortened)).monospacedDigit().font(.callout.weight(.semibold))
                        .frame(width: 60, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(a.clientName)
                        Text(a.template.nameEN).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !a.missingDocuments.isEmpty {
                        Pill(text: "\(a.missingDocuments.count) missing", tint: Theme.warn)
                    }
                    if let link = a.videoURL, let url = URL(string: link) {
                        Link(destination: url) { Image(systemName: "video") }
                    }
                }
            }
            Divider()
            HStack {
                Button("Open Advisor OS") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
