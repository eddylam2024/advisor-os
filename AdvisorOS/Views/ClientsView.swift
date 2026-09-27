import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Appointment.start) private var appointments: [Appointment]
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showingAdd = false
    @State private var importing = false
    @State private var exporting = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            if clients.isEmpty {
                EmptyStateView(title: "No clients yet", systemImage: "person.2",
                               message: "Add a client, or import a CSV exported from any CRM.")
            } else {
                Table(clients, selection: $selection) {
                    TableColumn("Client") { c in
                        HStack(spacing: 10) { Avatar(name: c.name, size: 26); Text(c.name) }
                    }
                    TableColumn("Email", value: \.email)
                    TableColumn("Language") { Text($0.preferredLanguage == "fr" ? "Français" : "English") }.width(90)
                    TableColumn("Next appointment") { c in Text(nextAppointment(for: c)).foregroundStyle(.secondary) }
                    TableColumn("KYC review") { c in kyc(c) }.width(110)
                    TableColumn("Came from", value: \.source).width(130)
                }
                .alternatingRowBackgrounds(.disabled)
                .scrollContentBackground(.hidden)
                .padding(6)
                .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
                .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
                    Button("Delete", role: .destructive) { delete(ids) }
                }
                .onDeleteCommand { delete(selection) }
            }
        }
        .padding(Theme.paddingLarge)
        .toolbar {
            ToolbarItemGroup {
                Button("Import CSV", systemImage: "square.and.arrow.down") { importing = true }
                Button("Export CSV", systemImage: "square.and.arrow.up") { exporting = true }
                    .disabled(clients.isEmpty)
                Button("Add Client", systemImage: "plus") { showingAdd = true }
            }
        }
        .sheet(isPresented: $showingAdd) { AddClientSheet() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            importCSV(result)
        }
        .fileExporter(isPresented: $exporting, document: CSVDocument(text: ClientCSV.export(clients)),
                      contentType: .commaSeparatedText, defaultFilename: "advisor-os-clients") { result in
            if case .success = result {
                context.log("\(clients.count) clients exported to CSV", by: "Advisor")
                message = "Exported \(clients.count) clients."
            }
        }
    }

    private func nextAppointment(for client: Client) -> String {
        guard let next = appointments.first(where: { $0.clientName == client.name && $0.end >= .now }) else { return "None booked" }
        return next.start.formatted(date: .abbreviated, time: .shortened)
    }

    @ViewBuilder private func kyc(_ client: Client) -> some View {
        if let due = client.kycReviewDue {
            if due <= .now {
                Pill(text: "Due now", tint: Theme.warn)
            } else if due <= Calendar.current.date(byAdding: .month, value: 3, to: .now)! {
                Pill(text: due.formatted(.dateTime.month(.abbreviated).year()), tint: .accentColor)
            } else {
                Pill(text: "Current", tint: Theme.good)
            }
        } else {
            Pill(text: "Not set")
        }
    }

    private func delete(_ ids: Set<PersistentIdentifier>) {
        for client in clients where ids.contains(client.persistentModelID) {
            context.log("Client \(client.name) deleted", by: "Advisor")
            context.delete(client)
        }
        selection.removeAll()
    }

    private func importCSV(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            message = "That file couldn't be read as UTF-8 text. Re-export it as CSV UTF-8 and try again."
            return
        }
        let rows = ClientCSV.parse(text)
        let existing = Set(clients.map { $0.name.lowercased() })
        let fresh = rows.filter { !existing.contains($0.name.lowercased()) }
        for row in fresh {
            context.insert(Client(name: row.name, email: row.email, phone: row.phone, preferredLanguage: row.language,
                                  kycReviewDue: row.kycReviewDue, source: "CSV import", notes: row.notes))
        }
        context.log("\(fresh.count) clients imported from \(url.lastPathComponent)", by: "Advisor")
        let skipped = rows.count - fresh.count
        message = "Imported \(fresh.count) clients" + (skipped > 0 ? ", skipped \(skipped) already in your list." : ".")
    }
}

struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct AddClientSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var language = "en"
    @State private var hasKYC = false
    @State private var kycDue = Date.now

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Email", text: $email)
            TextField("Phone", text: $phone)
            Picker("Language", selection: $language) {
                Text("English").tag("en")
                Text("Français").tag("fr")
            }
            Toggle("Set KYC review date", isOn: $hasKYC)
            if hasKYC { DatePicker("KYC review due", selection: $kycDue, displayedComponents: .date) }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add Client") {
                    context.insert(Client(name: name.trimmingCharacters(in: .whitespaces), email: email, phone: phone,
                                          preferredLanguage: language, kycReviewDue: hasKYC ? kycDue : nil))
                    context.log("Client \(name) added", by: "Advisor")
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
