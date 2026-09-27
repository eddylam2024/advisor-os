import Foundation
import SwiftData

@Model
final class Client {
    var name: String
    var email: String
    var phone: String
    var preferredLanguage: String
    var kycReviewDue: Date?
    var source: String
    var notes: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Appointment.client) var appointments: [Appointment] = []

    init(name: String, email: String = "", phone: String = "", preferredLanguage: String = "en",
         kycReviewDue: Date? = nil, source: String = "Added by hand", notes: String = "") {
        self.name = name
        self.email = email
        self.phone = phone
        self.preferredLanguage = preferredLanguage
        self.kycReviewDue = kycReviewDue
        self.source = source
        self.notes = notes
        self.createdAt = .now
    }
}

enum MeetingFormat: String, Codable, CaseIterable, Identifiable {
    case inPerson, video, phone, unknown
    var id: String { rawValue }
    var label: String {
        switch self {
        case .inPerson: "In person"
        case .video: "Video"
        case .phone: "Phone"
        case .unknown: "Format not set"
        }
    }
}

@Model
final class Appointment {
    var clientName: String
    var clientEmail: String
    var start: Date
    var durationMinutes: Int
    var templateID: String
    var formatRaw: String
    var videoURL: String?
    var calendarEventID: String?
    var receivedDocuments: [String]
    var notes: String
    var isDemo: Bool
    var client: Client?

    init(clientName: String, clientEmail: String = "", start: Date, durationMinutes: Int, templateID: String,
         format: MeetingFormat = .inPerson, videoURL: String? = nil, calendarEventID: String? = nil,
         receivedDocuments: [String] = [], notes: String = "", isDemo: Bool = false) {
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.start = start
        self.durationMinutes = durationMinutes
        self.templateID = templateID
        self.formatRaw = format.rawValue
        self.videoURL = videoURL
        self.calendarEventID = calendarEventID
        self.receivedDocuments = receivedDocuments
        self.notes = notes
        self.isDemo = isDemo
    }

    var format: MeetingFormat {
        get { MeetingFormat(rawValue: formatRaw) ?? .inPerson }
        set { formatRaw = newValue.rawValue }
    }

    var template: AppointmentTemplate { AppointmentTemplate.find(templateID) }

    /// Client-facing drafts use this. Unlinked appointments default to English.
    var language: String { client?.preferredLanguage ?? "en" }

    /// Missing documents named in the client's language.
    var missingDocumentsLocalized: [String] {
        let t = template
        return t.documents.en.indices.compactMap { i in
            receivedDocuments.contains(t.documents.en[i]) ? nil : t.documents.list(language)[i]
        }
    }

    /// Links this appointment to the matching client record, preferring email over name.
    func linkClient(from clients: [Client]) {
        guard client == nil else { return }
        client = ClientMatcher.match(name: clientName, email: clientEmail, in: clients)
        if let client, clientEmail.isEmpty { clientEmail = client.email }
    }

    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

    var missingDocuments: [String] {
        template.documents.en.filter { !receivedDocuments.contains($0) }
    }
}

enum DraftKind: String, Codable, CaseIterable {
    case brief, followUp, reminder, complianceNote

    var label: String {
        switch self {
        case .brief: "Meeting brief"
        case .followUp: "Follow-up email"
        case .reminder: "Reminder email"
        case .complianceNote: "Compliance note"
        }
    }

    var isEmail: Bool { self == .followUp || self == .reminder }

    /// Emails go to the client in their language. Briefs and compliance notes are internal and stay in English.
    var isClientFacing: Bool { isEmail }
}

enum DraftStatus: String, Codable {
    case ready, approved
}

@Model
final class Draft {
    var kindRaw: String
    var statusRaw: String
    var clientName: String
    var clientEmail: String
    var text: String
    var generatedBy: String
    var createdAt: Date
    var approvedAt: Date?
    var approvedBy: String?
    var language: String = "en"

    init(kind: DraftKind, clientName: String, clientEmail: String = "", text: String, generatedBy: String, language: String = "en") {
        self.kindRaw = kind.rawValue
        self.statusRaw = DraftStatus.ready.rawValue
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.text = text
        self.generatedBy = generatedBy
        self.createdAt = .now
        self.language = language
    }

    var kind: DraftKind { DraftKind(rawValue: kindRaw) ?? .brief }

    var status: DraftStatus {
        get { DraftStatus(rawValue: statusRaw) ?? .ready }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class AuditEntry {
    var date: Date
    var action: String
    var actor: String

    init(action: String, actor: String, date: Date = .now) {
        self.date = date
        self.action = action
        self.actor = actor
    }
}

extension ModelContext {
    /// Every meaningful change goes through here so the audit trail stays complete.
    func log(_ action: String, by actor: String) {
        insert(AuditEntry(action: action, actor: actor))
    }
}

nonisolated enum ClientMatcher {
    /// Email is the strongest match. Names only match exactly, ignoring case and extra spaces,
    /// so "J. Martin" and "Julie Martin" stay separate until the advisor links them.
    static func match(name: String, email: String, in clients: [Client]) -> Client? {
        let email = email.trimmingCharacters(in: .whitespaces)
        if !email.isEmpty, let byEmail = clients.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
            return byEmail
        }
        let key = normalized(name)
        guard !key.isEmpty else { return nil }
        return clients.first { normalized($0.name) == key }
    }

    static func normalized(_ name: String) -> String {
        name.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

extension ModelContext {
    /// Links any appointments that aren't tied to a client yet. Safe to run at every launch.
    func linkUnassignedAppointments() {
        let clients = (try? fetch(FetchDescriptor<Client>())) ?? []
        let unlinked = (try? fetch(FetchDescriptor<Appointment>(predicate: #Predicate { $0.client == nil }))) ?? []
        unlinked.forEach { $0.linkClient(from: clients) }
    }
}
