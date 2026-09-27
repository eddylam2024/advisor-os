import Foundation
import FoundationModels

/// Drafts briefs, follow-ups, reminders and compliance notes.
/// Uses Apple's on-device model when it's available, so client data never leaves the Mac.
/// Falls back to a plain template when it isn't (Apple Intelligence off, unsupported Mac, model still downloading).
@Observable
final class DraftingService {
    enum Engine: Equatable {
        case onDevice
        case template(reason: String)

        var label: String {
            switch self {
            case .onDevice: "On-device model"
            case .template: "Template"
            }
        }
    }

    var engine: Engine {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .onDevice
        case .unavailable(.appleIntelligenceNotEnabled):
            return .template(reason: "Apple Intelligence is turned off in System Settings.")
        case .unavailable(.deviceNotEligible):
            return .template(reason: "This Mac doesn't support Apple's on-device model.")
        case .unavailable(.modelNotReady):
            return .template(reason: "Apple's on-device model is still downloading.")
        case .unavailable:
            return .template(reason: "Apple's on-device model isn't available right now.")
        }
    }

    private static let instructions = """
    You draft working documents for a Canadian financial advisor or mortgage agent. \
    Write plainly and briefly. Use only the facts provided; if something is unknown, say it is to be confirmed. \
    Never recommend a product, never promise a rate or approval, and never give financial advice. \
    The advisor will review and edit everything before it is used.
    """

    /// The language a draft is written in: the client's for emails, English for internal documents.
    static func language(for kind: DraftKind, _ appointment: Appointment) -> String {
        kind.isClientFacing ? appointment.language : "en"
    }

    func draft(_ kind: DraftKind, for appointment: Appointment, advisorName: String) async -> (text: String, engine: String) {
        let fallback = Self.templateDraft(kind, for: appointment, advisorName: advisorName)
        guard engine == .onDevice else { return (fallback, Engine.template(reason: "").label) }
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            var prompt = Self.prompt(kind, for: appointment, advisorName: advisorName)
            if Self.language(for: kind, appointment) == "fr" {
                prompt += "\n\nWrite the email in natural Canadian French (Québec), using vous. Use the French document names given."
            }
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? (fallback, Engine.template(reason: "").label) : (text, Engine.onDevice.label)
        } catch {
            return (fallback, Engine.template(reason: "").label)
        }
    }

    private static func facts(for a: Appointment) -> String {
        let t = a.template
        let received = a.receivedDocuments.isEmpty ? "none yet" : a.receivedDocuments.joined(separator: "; ")
        let missing = a.missingDocuments.isEmpty ? "none" : a.missingDocuments.joined(separator: "; ")
        return """
        Client: \(a.clientName)
        Appointment: \(t.nameEN), \(a.start.formatted(date: .abbreviated, time: .shortened)), \(a.durationMinutes) minutes, \(a.format.label)
        Agenda: \(t.agenda.joined(separator: "; "))
        Documents received: \(received)
        Documents missing: \(missing)
        Missing documents in French: \(a.missingDocumentsLocalized.isEmpty || a.language != "fr" ? "n/a" : a.missingDocumentsLocalized.joined(separator: "; "))
        Advisor notes: \(a.notes.isEmpty ? "none" : a.notes)
        """
    }

    private static func prompt(_ kind: DraftKind, for a: Appointment, advisorName: String) -> String {
        let task: String = switch kind {
        case .brief:
            "Write a meeting brief with short sections: Purpose, What we have, What's missing, Talking points. Use bullet points."
        case .followUp:
            "Write a short, warm follow-up email to the client after the meeting, signed by \(advisorName). Summarize next steps and list any missing documents. No subject line."
        case .reminder:
            "Write a short, friendly email reminding the client to bring or upload the missing documents before the appointment, signed by \(advisorName). No subject line."
        case .complianceNote:
            "Write a factual file note for the compliance record: date, meeting type, attendees, documents received, topics to cover, and a line stating no recommendation has been recorded yet."
        }
        return "\(task)\n\nFacts:\n\(facts(for: a))"
    }

    /// Deterministic drafts used when the on-device model isn't available.
    static func templateDraft(_ kind: DraftKind, for a: Appointment, advisorName: String) -> String {
        if language(for: kind, a) == "fr", let french = frenchTemplateDraft(kind, for: a, advisorName: advisorName) {
            return french
        }
        let t = a.template
        let when = a.start.formatted(date: .complete, time: .shortened)
        let missing = a.missingDocuments
        let missingList = missing.map { "• \($0)" }.joined(separator: "\n")
        switch kind {
        case .brief:
            return """
            \(t.nameEN) · \(a.clientName) · \(a.start.formatted(date: .omitted, time: .shortened))

            What we have
            \(a.receivedDocuments.isEmpty ? "• No documents received yet" : a.receivedDocuments.map { "• \($0)" }.joined(separator: "\n"))

            What's missing
            \(missing.isEmpty ? "• Nothing" : missingList)

            Agenda
            \(t.agenda.map { "• \($0)" }.joined(separator: "\n"))
            \(a.notes.isEmpty ? "" : "\nNotes\n\(a.notes)")
            """
        case .followUp:
            return """
            Hi \(a.clientName),

            Thank you for meeting with me today about your \(t.nameEN.lowercased()).
            \(missing.isEmpty ? "I have everything I need for now, and I'll follow up with next steps shortly." : "To move forward, please send the following:\n\n\(missingList)")

            Don't hesitate to reach out with any questions.

            \(advisorName)
            """
        case .reminder:
            return """
            Hi \(a.clientName),

            A quick reminder about our \(t.nameEN.lowercased()) appointment on \(when).
            \(missing.isEmpty ? "You're all set. There's nothing else to bring." : "Please bring or send these documents beforehand:\n\n\(missingList)")

            See you soon,
            \(advisorName)
            """
        case .complianceNote:
            return """
            File note · \(a.start.formatted(date: .numeric, time: .shortened))
            Client: \(a.clientName)
            Meeting: \(t.nameEN), \(a.format.label.lowercased()), \(a.durationMinutes) min
            Documents received: \(a.receivedDocuments.isEmpty ? "none" : a.receivedDocuments.joined(separator: ", "))
            Outstanding: \(missing.isEmpty ? "none" : missing.joined(separator: ", "))
            Topics: \(t.agenda.joined(separator: "; "))
            No recommendation recorded at the time of this note.
            """
        }
    }

    /// French versions of the client-facing emails.
    private static func frenchTemplateDraft(_ kind: DraftKind, for a: Appointment, advisorName: String) -> String? {
        let t = a.template
        let missing = a.missingDocumentsLocalized
        let missingList = missing.map { "• \($0)" }.joined(separator: "\n")
        let when = a.start.formatted(Date.FormatStyle(date: .complete, time: .shortened).locale(Locale(identifier: "fr_CA")))
        switch kind {
        case .followUp:
            return """
            Bonjour \(a.clientName),

            Merci pour notre rencontre d'aujourd'hui au sujet de votre \(t.nameFR.lowercased()).
            \(missing.isEmpty ? "J'ai tout ce qu'il me faut pour l'instant. Je vous reviens bientôt avec la suite." : "Pour aller de l'avant, pourriez-vous m'envoyer les documents suivants :\n\n\(missingList)")

            N'hésitez pas à me joindre si vous avez des questions.

            \(advisorName)
            """
        case .reminder:
            return """
            Bonjour \(a.clientName),

            Petit rappel de notre rendez-vous (\(t.nameFR.lowercased())) le \(when).
            \(missing.isEmpty ? "Tout est en ordre, vous n'avez rien d'autre à apporter." : "Merci d'apporter ou de m'envoyer ces documents avant la rencontre :\n\n\(missingList)")

            Au plaisir,
            \(advisorName)
            """
        case .brief, .complianceNote:
            return nil
        }
    }
}
