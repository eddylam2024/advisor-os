import SwiftData
import SwiftUI

struct AddAppointmentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarService.self) private var calendar
    @AppStorage("advisorName") private var advisorName = ""
    @AppStorage("lastCalendarForNewAppointments") private var lastCalendarID = ""
    @Query(sort: \Client.name) private var clients: [Client]

    var onCreated: (Appointment) -> Void = { _ in }

    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var templateID = AppointmentTemplate.all[0].id
    @State private var start = AddAppointmentSheet.nextHalfHour()
    @State private var minutes = AppointmentTemplate.all[0].minutes
    @State private var format: MeetingFormat = .inPerson
    @State private var videoURL = ""
    @State private var notes = ""
    @State private var addToCalendar = true
    @State private var calendarID = ""
    @State private var errorMessage: String?

    private var canWriteCalendar: Bool { calendar.isSyncing && !calendar.writableWorkCalendars.isEmpty }
    private var trimmedName: String { clientName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            Section("Client") {
                TextField("Name", text: $clientName, prompt: Text("e.g. J. Martin"))
                    .textContentType(.name)
                if !clients.isEmpty {
                    Picker("Existing client", selection: Binding(
                        get: { clients.first { $0.name == clientName }?.persistentModelID },
                        set: { id in
                            if let c = clients.first(where: { $0.persistentModelID == id }) {
                                clientName = c.name
                                clientEmail = c.email
                            }
                        })) {
                        Text("None").tag(PersistentIdentifier?.none)
                        ForEach(clients) { Text($0.name).tag(Optional($0.persistentModelID)) }
                    }
                }
                TextField("Email", text: $clientEmail, prompt: Text("For reminders and follow-ups"))
            }

            Section("Appointment") {
                Picker("Type", selection: $templateID) {
                    ForEach(AppointmentTemplate.all) { Text($0.nameEN).tag($0.id) }
                }
                .onChange(of: templateID) { minutes = AppointmentTemplate.find(templateID).minutes }
                DatePicker("Starts", selection: $start)
                Stepper("Length: \(minutes) min", value: $minutes, in: 15...240, step: 15)
                Picker("Format", selection: $format) {
                    ForEach([MeetingFormat.inPerson, .video, .phone]) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if format == .video {
                    TextField("Video link", text: $videoURL, prompt: Text("Teams, Zoom or Meet link"))
                }
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
            }

            Section {
                if canWriteCalendar {
                    Toggle("Also add to my calendar", isOn: $addToCalendar)
                    if addToCalendar {
                        Picker("Calendar", selection: $calendarID) {
                            ForEach(calendar.writableWorkCalendars) { Text("\($0.title) · \($0.account)").tag($0.id) }
                        }
                    }
                } else {
                    Text("Connect your calendar in Connections to add appointments to it as well.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Calendar")
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 560)
        .onAppear {
            let writable = calendar.writableWorkCalendars.map(\.id)
            calendarID = writable.contains(lastCalendarID) ? lastCalendarID : (writable.first ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add Appointment", action: save).disabled(trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        let link = videoURL.trimmingCharacters(in: .whitespaces)
        let appointment = Appointment(clientName: trimmedName, clientEmail: clientEmail.trimmingCharacters(in: .whitespaces),
                                      start: start, durationMinutes: minutes, templateID: templateID, format: format,
                                      videoURL: format == .video && !link.isEmpty ? link : nil, notes: notes)
        if canWriteCalendar && addToCalendar && !calendarID.isEmpty {
            do {
                appointment.calendarEventID = try calendar.createEvent(for: appointment, calendarID: calendarID)
                lastCalendarID = calendarID
            } catch {
                errorMessage = "Couldn't add it to your calendar: \(error.localizedDescription)"
                return
            }
        }
        context.insert(appointment)
        if let existing = ClientMatcher.match(name: trimmedName, email: appointment.clientEmail, in: clients) {
            appointment.client = existing
        } else {
            let client = Client(name: trimmedName, email: appointment.clientEmail)
            context.insert(client)
            appointment.client = client
        }
        let by = advisorName.isEmpty ? "Advisor" : advisorName
        context.log("\(appointment.template.nameEN) with \(trimmedName) added for \(start.formatted(date: .abbreviated, time: .shortened))"
                    + (appointment.calendarEventID != nil ? " and to Calendar" : ""), by: by)
        try? context.save()
        onCreated(appointment)
        dismiss()
    }

    private static func nextHalfHour() -> Date {
        let now = Date.now
        let minute = Calendar.current.component(.minute, from: now)
        let rounded = Calendar.current.date(byAdding: .minute, value: minute < 30 ? 30 - minute : 60 - minute, to: now)!
        return Calendar.current.date(bySetting: .second, value: 0, of: rounded) ?? rounded
    }
}
