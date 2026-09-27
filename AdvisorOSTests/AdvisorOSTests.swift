import Foundation
import FoundationModels
import Testing
@testable import Advisor_OS

struct TemplateMatchingTests {
    @Test(arguments: [
        ("Annual review – J. Martin", "review"),
        ("Mortgage renewal - A. Nguyen", "renewal"),
        ("Pre-approval with S. Côté", "preapproval"),
        ("Ouverture de compte: R. Gagnon", "open"),
        ("HELOC | M. Tremblay", "heloc"),
        ("Coffee with Sam", "general")
    ])
    func matchesTemplateFromTitle(title: String, expected: String) {
        #expect(AppointmentTemplate.match(title: title).id == expected)
    }

    @Test(arguments: [
        ("Annual review – J. Martin", "J. Martin"),
        ("J. Martin: annual review", "J. Martin"),
        ("Renewal with A. Nguyen", "A. Nguyen"),
        ("Revue annuelle avec Sophie Côté", "Sophie Côté"),
        ("R. Gagnon", "R. Gagnon")
    ])
    func extractsClientName(title: String, expected: String) {
        #expect(EventTitleParser.clientName(from: title) == expected)
    }

    @Test func everyTemplateHasMatchingFrenchChecklist() {
        for t in AppointmentTemplate.all {
            #expect(t.documents.en.count == t.documents.fr.count, "\(t.id) EN and FR checklists differ in length")
        }
    }
}

struct ClientCSVTests {
    @Test func parsesQuotedFieldsAndCommonHeaders() {
        let csv = #"""
        Full Name,E-mail,Phone,Langue,Notes
        "Côté, Sophie",s.cote@example.com,514-555-0100,Français,"Said ""call after 5"""
        J. Martin,j.martin@example.com,,English,
        ,nobody@example.com,,,
        """#
        let rows = ClientCSV.parse(csv)
        #expect(rows.count == 2)
        #expect(rows[0].name == "Côté, Sophie")
        #expect(rows[0].language == "fr")
        #expect(rows[0].notes == "Said \"call after 5\"")
        #expect(rows[1].email == "j.martin@example.com")
        #expect(rows[1].language == "en")
    }

    @Test func combinesFirstAndLastName() {
        let rows = ClientCSV.parse("First Name,Last Name,Email\nAnh,Nguyen,a@example.com\n")
        #expect(rows.first?.name == "Anh Nguyen")
    }

    @Test func handlesWindowsLineEndingsAndNewlinesInQuotes() {
        let records = ClientCSV.parseRecords("name,notes\r\n\"A\",\"line 1\nline 2\"\r\n")
        #expect(records == [["name", "notes"], ["A", "line 1\nline 2"]])
    }
}

struct MailServiceTests {
    @Test func encodesSpacesAndPlusSigns() throws {
        let url = try #require(MailService.draftURL(to: "a@example.com", subject: "RRSP + TFSA", body: "Hi there"))
        let s = url.absoluteString
        #expect(s.hasPrefix("mailto:a@example.com?"))
        #expect(s.contains("RRSP%20%2B%20TFSA"))
        #expect(s.contains("Hi%20there"))
    }
}

@MainActor
struct DraftingTests {
    private func sampleAppointment() -> Appointment {
        Appointment(clientName: "S. Côté", clientEmail: "s.cote@example.com", start: .now.addingTimeInterval(7200),
                    durationMinutes: 60, templateID: "preapproval", format: .video,
                    receivedDocuments: ["Government photo ID"], notes: "First home in Laval, budget around $540,000.")
    }

    @Test func templateDraftListsMissingDocuments() {
        let text = DraftingService.templateDraft(.reminder, for: sampleAppointment(), advisorName: "E. Lam")
        #expect(text.contains("Letter of employment"))
        #expect(!text.contains("• Government photo ID"))
        #expect(text.hasSuffix("E. Lam"))
    }

    /// Exercises Apple's on-device model for real. Skipped on Macs without Apple Intelligence.
    @Test(.enabled(if: SystemLanguageModel.default.isAvailable), .timeLimit(.minutes(2)))
    func onDeviceModelWritesABrief() async {
        let result = await DraftingService().draft(.brief, for: sampleAppointment(), advisorName: "E. Lam")
        print("---- On-device brief (\(result.engine)) ----\n\(result.text)\n----")
        #expect(result.engine == "On-device model")
        #expect(result.text.count > 80)
    }
}
