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

    init(kind: DraftKind, clientName: String, clientEmail: String = "", text: String, generatedBy: String) {
        self.kindRaw = kind.rawValue
        self.statusRaw = DraftStatus.ready.rawValue
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.text = text
        self.generatedBy = generatedBy
        self.createdAt = .now
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
