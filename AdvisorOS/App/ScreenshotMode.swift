#if DEBUG
import AppKit
import SwiftData

/// Debug-only mode for documentation screenshots: an in-memory database filled with fictional data,
/// with the real calendar and mail app kept out of frame. Launch with `-screenshotMode YES`.
enum ScreenshotMode {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "screenshotMode") }

    static func applyAppearance() {
        switch UserDefaults.standard.string(forKey: "appearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
    }

    static func seed(_ context: ModelContext) {
        DemoData.load(into: context)
        let appointments = (try? context.fetch(FetchDescriptor<Appointment>(sortBy: [SortDescriptor(\.start)]))) ?? []
        func appointment(_ name: String) -> Appointment? { appointments.first { $0.clientName == name } }
        let advisor = UserDefaults.standard.string(forKey: "advisorName") ?? "Advisor"

        var drafts: [Draft] = []
        if let gagnon = appointment("R. Gagnon") {
            drafts.append(Draft(kind: .complianceNote, clientName: gagnon.clientName, clientEmail: gagnon.clientEmail,
                                text: DraftingService.templateDraft(.complianceNote, for: gagnon, advisorName: advisor),
                                generatedBy: "On-device model"))
        }
        if let cote = appointment("S. Côté") {
            drafts.append(Draft(kind: .reminder, clientName: cote.clientName, clientEmail: cote.clientEmail,
                                text: DraftingService.templateDraft(.reminder, for: cote, advisorName: advisor),
                                generatedBy: "On-device model", language: "fr"))
        }
        if let martin = appointment("J. Martin") {
            let approved = Draft(kind: .followUp, clientName: martin.clientName, clientEmail: martin.clientEmail,
                                 text: DraftingService.templateDraft(.followUp, for: martin, advisorName: advisor),
                                 generatedBy: "On-device model")
            approved.status = .approved
            approved.approvedAt = Calendar.current.date(bySettingHour: 9, minute: 14, second: 0, of: .now)
            approved.approvedBy = advisor
            drafts.append(approved)
        }
        drafts.forEach(context.insert)

        let today = Calendar.current.startOfDay(for: .now)
        func at(_ h: Int, _ m: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: today)! }
        [("Meeting brief drafted for J. Martin (On-device model)", "AI", at(9, 2)),
         ("Follow-up email for J. Martin approved", advisor, at(9, 14)),
         ("Reminder email drafted for S. Côté (On-device model)", "AI", at(9, 20)),
         ("Government photo ID marked received for S. Côté", advisor, at(9, 31)),
         ("Compliance note drafted for R. Gagnon (On-device model)", "AI", at(9, 40))]
            .forEach { context.insert(AuditEntry(action: $0.0, actor: $0.1, date: $0.2)) }
        try? context.save()
    }
}
#endif
