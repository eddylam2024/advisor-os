import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(CalendarService.self) private var calendar
    @Query(sort: \Appointment.start) private var appointments: [Appointment]
    @State private var selectedID: PersistentIdentifier?
    @State private var showingAdd = false
    @State private var pendingDelete: Appointment?
    @State private var deleteError: String?

    private var today: [Appointment] {
        appointments.filter { Calendar.current.isDateInToday($0.start) }
    }

    private var upcoming: [Appointment] {
        let tomorrow = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400)
        return appointments.filter { $0.start >= tomorrow }
    }

    private var selected: Appointment? {
        appointments.first { $0.persistentModelID == selectedID } ?? today.first ?? upcoming.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.gapLarge) {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Text(summary).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if today.isEmpty && upcoming.isEmpty {
                            EmptyStateView(title: "No appointments", systemImage: "calendar",
                                           message: "Add one with the + button, connect your calendar in Connections, or load demo data in Settings.")
                        }
                        if !today.isEmpty {
                            SectionLabel("Today")
                            ForEach(today) { row($0, showDate: false) }
                        }
                        if !upcoming.isEmpty {
                            SectionLabel("Next 14 days").padding(.top, 8)
                            ForEach(upcoming) { row($0, showDate: true) }
                        }
                    }
                    .padding(2)
                }
            }
            .frame(width: 320)

            if let selected {
                AppointmentDetailView(appointment: selected) { pendingDelete = $0 }
                    .id(selected.persistentModelID)
            } else {
                Spacer()
            }
        }
        .padding(Theme.paddingLarge)
        .toolbar {
            ToolbarItemGroup {
                if calendar.isSyncing {
                    Button("Refresh from Calendar", systemImage: "arrow.clockwise") { calendar.sync(into: context) }
                }
                Button("New Appointment", systemImage: "plus") { showingAdd = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddAppointmentSheet { selectedID = $0.persistentModelID }
        }
        .confirmationDialog(deleteTitle, isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { appointment in
            Button(appointment.calendarEventID != nil ? "Delete from Advisor OS and Calendar" : "Delete Appointment", role: .destructive) {
                delete(appointment)
            }
        } message: { appointment in
            Text(appointment.calendarEventID != nil
                 ? "This also deletes the event from your calendar. Notes and document checkmarks for it are lost."
                 : "Notes and document checkmarks for it are lost.")
        }
        .alert("Couldn't delete the calendar event", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func row(_ appointment: Appointment, showDate: Bool) -> some View {
        AppointmentRow(appointment: appointment, isSelected: appointment.persistentModelID == selected?.persistentModelID, showDate: showDate) {
            selectedID = $0
        }
        .contextMenu {
            Button("Delete Appointment…", role: .destructive) { pendingDelete = appointment }
        }
    }

    private var deleteTitle: String {
        guard let a = pendingDelete else { return "" }
        return "Delete \(a.template.nameEN.lowercased()) with \(a.clientName)?"
    }

    private func delete(_ appointment: Appointment) {
        if let eventID = appointment.calendarEventID {
            do {
                try calendar.deleteEvent(id: eventID)
            } catch {
                deleteError = error.localizedDescription
                return
            }
        }
        context.log("\(appointment.template.nameEN) with \(appointment.clientName) deleted"
                    + (appointment.calendarEventID != nil ? " from Advisor OS and Calendar" : ""), by: "Advisor")
        if selectedID == appointment.persistentModelID { selectedID = nil }
        context.delete(appointment)
        try? context.save()
        pendingDelete = nil
    }

    private var summary: String {
        let source = calendar.isSyncing ? "from Calendar on this Mac" : "calendar not connected"
        let synced = calendar.lastSync.map { ", updated \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
        return "\(today.count) today · \(source)\(synced)"
    }
}

struct AppointmentRow: View {
    let appointment: Appointment
    let isSelected: Bool
    var showDate = false
    let onSelect: (PersistentIdentifier) -> Void

    var body: some View {
        let t = appointment.template
        let total = t.documents.en.count
        let got = total - appointment.missingDocuments.count
        Button {
            onSelect(appointment.persistentModelID)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    if showDate {
                        Text(appointment.start.formatted(.dateTime.weekday(.abbreviated).day())).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(appointment.start.formatted(date: .omitted, time: .shortened)).font(.callout.weight(.semibold)).monospacedDigit()
                }
                .frame(width: 60, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appointment.clientName).font(.body.weight(.medium))
                    Text(appointment.format == .unknown ? t.nameEN : "\(t.nameEN) · \(appointment.format.label)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if total > 0 {
                    Pill(text: got == total ? "All documents" : "\(got)/\(total)",
                         tint: got == total ? Theme.good : (Double(got) / Double(total) < 0.5 ? Theme.warn : .secondary))
                }
            }
            .padding(12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusBox))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusBox)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
    }
}

struct AppointmentDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(DraftingService.self) private var drafting
    @AppStorage("advisorName") private var advisorName = ""
    @Bindable var appointment: Appointment
    var onDelete: (Appointment) -> Void = { _ in }
    @State private var working: DraftKind?
    @State private var latestDraft: Draft?

    var body: some View {
        let t = appointment.template
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gapLarge) {
                header(t)
                HStack(alignment: .top, spacing: Theme.gapLarge) {
                    documents(t)
                    VStack(alignment: .leading, spacing: Theme.gap) {
                        SectionLabel("Agenda")
                        ForEach(t.agenda, id: \.self) { item in
                            Label(item, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                        }
                    }
                    .glassCard()
                }
                notes
                drafts
            }
            .padding(2)
        }
    }

    private func header(_ t: AppointmentTemplate) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Avatar(name: appointment.clientName, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.clientName).font(.title2.weight(.semibold))
                Text("\(t.nameEN) · \(appointment.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())) · \(appointment.durationMinutes) min")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let link = appointment.videoURL, let url = URL(string: link) {
                Link(destination: url) { Label("Join video", systemImage: "video") }
                    .buttonStyle(.glass)
            }
            if appointment.isDemo { Pill(text: "Demo", tint: Theme.warn) }
            Menu {
                Picker("Appointment type", selection: $appointment.templateID) {
                    ForEach(AppointmentTemplate.all) { Text($0.nameEN).tag($0.id) }
                }
                Divider()
                Button("Delete Appointment…", systemImage: "trash", role: .destructive) { onDelete(appointment) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .glassCard()
    }

    private func documents(_ t: AppointmentTemplate) -> some View {
        let docs = t.documents.en
        let got = docs.count - appointment.missingDocuments.count
        return VStack(alignment: .leading, spacing: Theme.gap) {
            HStack {
                SectionLabel("Documents from client")
                Spacer()
                if !docs.isEmpty { Text("\(got) of \(docs.count)").font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
            if docs.isEmpty {
                Text("This appointment type has no checklist.").foregroundStyle(.secondary)
            } else {
                ProgressView(value: Double(got), total: Double(docs.count)).tint(Theme.good)
                ForEach(docs, id: \.self) { doc in
                    Toggle(isOn: received(doc)) { Text(doc) }
                        .toggleStyle(.checkbox)
                }
            }
        }
        .glassCard()
    }

    private func received(_ doc: String) -> Binding<Bool> {
        Binding {
            appointment.receivedDocuments.contains(doc)
        } set: { isOn in
            if isOn {
                appointment.receivedDocuments.append(doc)
                context.log("\(doc) marked received for \(appointment.clientName)", by: advisorLabel)
            } else {
                appointment.receivedDocuments.removeAll { $0 == doc }
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            SectionLabel("Notes")
            TextEditor(text: $appointment.notes)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Theme.radiusButton))
        }
        .glassCard()
    }

    private var drafts: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            HStack {
                SectionLabel("Drafts")
                Spacer()
                Text("Engine: \(drafting.engine.label)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(DraftKind.allCases, id: \.self) { kind in
                    Button {
                        Task { await makeDraft(kind) }
                    } label: {
                        if working == kind { ProgressView().controlSize(.small) } else { Text(kind.label) }
                    }
                    .buttonStyle(.glass)
                    .disabled(working != nil)
                }
            }
            if let latestDraft {
                Text("\(latestDraft.kind.label) sent to Approvals.").font(.callout.weight(.medium))
                Text(latestDraft.text)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Theme.radiusBox))
            } else {
                Text("Drafts wait in Approvals. Nothing is sent or filed until you approve it.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    private var advisorLabel: String { advisorName.isEmpty ? "Advisor" : advisorName }

    private func makeDraft(_ kind: DraftKind) async {
        working = kind
        defer { working = nil }
        let result = await drafting.draft(kind, for: appointment, advisorName: advisorLabel)
        let draft = Draft(kind: kind, clientName: appointment.clientName, clientEmail: appointment.clientEmail,
                          text: result.text, generatedBy: result.engine)
        context.insert(draft)
        context.log("\(kind.label) drafted for \(appointment.clientName) (\(result.engine))", by: "AI")
        latestDraft = draft
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().frame(width: 5, height: 5).foregroundStyle(.secondary).alignmentGuide(.firstTextBaseline) { $0[.bottom] + 1 }
            configuration.title
        }
    }
}
